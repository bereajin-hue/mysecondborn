import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/env.dart';
import '../../../core/services/gemini_service.dart';

class ScanRepository {
  final _supabase = Supabase.instance.client;

  // 오늘 사용량이 하드 리밋(20회)에 도달했는지 확인
  Future<bool> isDailyLimitReached(String userId) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final res = await _supabase
          .from('usage_limits')
          .select('scan_count')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();
      if (res == null) return false;
      return (res['scan_count'] as int) >= AppConfig.geminiDailyLimit;
    } catch (_) {
      return false; // 테이블 없거나 오류 시 제한 없이 통과
    }
  }

  // 규칙 6번: 1024x1024 이하로 리사이즈 + JPEG 80% 압축
  Uint8List _compress(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) throw Exception('이미지를 읽을 수 없어요. 다른 사진으로 시도해주세요.');

    final maxDim = AppConfig.maxImageDimension;
    final needsResize = decoded.width > maxDim || decoded.height > maxDim;
    final resized = needsResize
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDim : null,
            height: decoded.height > decoded.width ? maxDim : null,
          )
        : decoded;

    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  Future<String> _uploadToStorage(Uint8List bytes, String userId) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _supabase.storage.from('scans').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } catch (e, s) {
      try {
        await Sentry.captureException(e, stackTrace: s);
      } catch (_) {}
      throw Exception('사진을 올리는 중 문제가 생겼어요. 다시 시도해주세요.');
    }
    return _supabase.storage.from('scans').getPublicUrl(path);
  }

  Future<void> _incrementUsage(String userId) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final existing = await _supabase
          .from('usage_limits')
          .select('scan_count')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('usage_limits').insert({
          'user_id': userId,
          'date': today,
          'scan_count': 1,
        });
      } else {
        await _supabase.from('usage_limits').update({
          'scan_count': (existing['scan_count'] as int) + 1,
        }).eq('user_id', userId).eq('date', today);
      }
    } catch (_) {
      // 사용량 집계 실패는 분석 흐름을 막지 않음
    }
  }

  /// 메인 플로우: 압축 → 업로드 → scan 레코드 생성 → Gemini 분석 → scanId 반환
  Future<String> captureAndAnalyze(XFile xfile, String userId) async {
    // ① 압축 (규칙 6번 엄수)
    final raw = await xfile.readAsBytes();
    final compressed = _compress(raw);

    // ② Storage 업로드
    final imageUrl = await _uploadToStorage(compressed, userId);

    // ③ scans 레코드 생성 (gemini_response null — 아직 분석 전)
    final Map<String, dynamic> scanRow;
    try {
      scanRow = await _supabase
          .from('scans')
          .insert({'user_id': userId, 'raw_image_url': imageUrl})
          .select()
          .single();
    } catch (e, s) {
      try {
        await Sentry.captureException(e, stackTrace: s);
      } catch (_) {}
      throw Exception('분석 기록 저장 중 문제가 생겼어요. 다시 시도해주세요.');
    }
    final scanId = scanRow['id'] as String;

    // ④ 사용량 증가
    await _incrementUsage(userId);

    // ⑤ Gemini 분석 — 성공·실패 모두 scans 테이블에 기록
    try {
      final prompt = await rootBundle.loadString('prompts/product_analysis.md');
      final gemini = GeminiService(apiKey: Env.geminiApiKey, prompt: prompt);
      final result = await gemini.analyzeBytes(compressed, 'image/jpeg');
      await _supabase
          .from('scans')
          .update({'gemini_response': result})
          .eq('id', scanId);
    } catch (e, s) {
      try {
        await Sentry.captureException(e, stackTrace: s);
      } catch (_) {}
      final msg = e is GeminiException
          ? e.userMessage
          : '잠깐 문제가 생겼어요. 다시 시도해주세요.';
      await _supabase
          .from('scans')
          .update({'gemini_response': <String, dynamic>{'error': msg}})
          .eq('id', scanId);
    }

    // ⑥ scanId 반환 — ResultScreen이 DB에서 직접 조회
    return scanId;
  }
}
