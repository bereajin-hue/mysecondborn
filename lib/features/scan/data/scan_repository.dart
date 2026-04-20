import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

class ScanRepository {
  final _supabase = Supabase.instance.client;

  // 오늘 사용량이 하드 리밋(20회)에 도달했는지 확인
  Future<bool> isDailyLimitReached(String userId) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final res = await _supabase
          .from('usage_limits')
          .select('count')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();
      if (res == null) return false;
      return (res['count'] as int) >= AppConfig.geminiDailyLimit;
    } catch (_) {
      return false;
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

  // 파일 크기 + 샘플링된 바이트로 간단한 해시 계산 (crypto 패키지 없이 구현)
  String _computeHash(Uint8List bytes) {
    var h = 5381;
    final step = (bytes.length / 256).ceil().clamp(1, bytes.length);
    for (var i = 0; i < bytes.length; i += step) {
      h = ((h << 5) + h + bytes[i]) & 0xFFFFFFFF;
    }
    return '${bytes.length}_${h.toRadixString(16)}';
  }

  // 동일 해시를 가진 성공한 분석 결과 조회 (사용자 전체 대상)
  // gemini_response와 product_id를 함께 반환 — 캐시 히트 시 product_id 전파를 위해
  Future<Map<String, dynamic>?> _checkCache(String hash) async {
    try {
      final res = await _supabase
          .from('scans')
          .select('gemini_response, product_id')
          .eq('image_hash', hash)
          .not('gemini_response', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      final data = res['gemini_response'] as Map<String, dynamic>?;
      // 에러 응답은 캐시 히트로 사용하지 않음
      if (data == null || data.containsKey('error')) return null;
      return res; // {gemini_response: {...}, product_id: 'uuid' or null}
    } catch (_) {
      return null;
    }
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
          .select('count')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('usage_limits').insert({
          'user_id': userId,
          'date': today,
          'count': 1,
        });
      } else {
        await _supabase.from('usage_limits').update({
          'count': (existing['count'] as int) + 1,
        }).eq('user_id', userId).eq('date', today);
      }
    } catch (_) {}
  }

  /// 메인 플로우:
  /// 1) 압축 + 해시 계산
  /// 2) 캐시 히트 → 기존 결과 복사하여 scan 생성 (Gemini 호출 없음)
  /// 3) 캐시 미스 → scan 생성 후 Edge Function을 백그라운드 실행
  ///    ResultScreen이 실시간 구독으로 완료를 감지
  Future<String> captureAndAnalyze(XFile xfile, String userId) async {
    final raw = await xfile.readAsBytes();
    final compressed = _compress(raw);
    final hash = _computeHash(compressed);

    // 캐시 확인 — 동일 이미지면 Gemini 재호출 불필요
    final cached = await _checkCache(hash);
    final imageUrl = await _uploadToStorage(compressed, userId);

    if (cached != null) {
      final geminiResponse = cached['gemini_response'] as Map<String, dynamic>;
      var productId = cached['product_id'] as String?;

      // 원본 스캔에 product_id가 없으면 (products 테이블 생성 전 스캔)
      // 지금 products 테이블에서 찾거나 새로 생성
      if (productId == null) {
        final name = geminiResponse['product_name'] as String?;
        final brand = (geminiResponse['brand'] as String?) ?? '';
        if (name != null) {
          try {
            final existing = await _supabase
                .from('products')
                .select('id')
                .eq('name', name)
                .eq('brand', brand)
                .maybeSingle();
            if (existing != null) {
              productId = existing['id'] as String;
            } else {
              final inserted = await _supabase
                  .from('products')
                  .insert({
                    'name': name,
                    'brand': brand.isEmpty ? null : brand,
                    'ingredients': geminiResponse['main_ingredients'] ?? [],
                    'image_url': imageUrl,
                  })
                  .select('id')
                  .single();
              productId = inserted['id'] as String;
            }
          } catch (_) {}
        }
      }

      // 캐시 히트: 결과를 바로 저장하여 ResultScreen에서 즉시 표시
      final row = await _supabase
          .from('scans')
          .insert({
            'user_id': userId,
            'raw_image_url': imageUrl,
            'image_hash': hash,
            'gemini_response': geminiResponse,
            if (productId != null) 'product_id': productId,
          })
          .select()
          .single();
      await _incrementUsage(userId);
      return row['id'] as String;
    }

    // 캐시 미스: scan 레코드를 먼저 생성하고 Edge Function에 위임
    final Map<String, dynamic> row;
    try {
      row = await _supabase
          .from('scans')
          .insert({
            'user_id': userId,
            'raw_image_url': imageUrl,
            'image_hash': hash,
          })
          .select()
          .single();
    } catch (e, s) {
      try {
        await Sentry.captureException(e, stackTrace: s);
      } catch (_) {}
      throw Exception('분석 기록 저장 중 문제가 생겼어요. 다시 시도해주세요.');
    }

    final scanId = row['id'] as String;
    await _incrementUsage(userId);

    // Edge Function을 백그라운드 실행 — gemini_response 업데이트를 ResultScreen이 실시간 구독
    _supabase.functions
        .invoke('analyze-product', body: {'scan_id': scanId})
        .then((_) {})
        .catchError((_) {});

    return scanId;
  }

  // 캐비닛에 저장
  Future<void> saveToMyCabinet(String userId, String productId) async {
    final existing = await _supabase
        .from('cabinet')
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) throw Exception('이미 내 영양제에 저장되어 있어요!');

    await _supabase.from('cabinet').insert({
      'user_id': userId,
      'product_id': productId,
    });
  }

  // 캐비닛 목록 조회 — cabinet + scans 2쿼리로 N+1 없이 조합
  Future<List<Map<String, dynamic>>> getCabinetItems(String userId) async {
    final cabinetRows = await _supabase
        .from('cabinet')
        .select('id, product_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if ((cabinetRows as List).isEmpty) return [];

    final productIds = cabinetRows.map((r) => r['product_id'] as String).toList();

    final scanRows = await _supabase
        .from('scans')
        .select('id, product_id, raw_image_url, gemini_response')
        .eq('user_id', userId)
        .inFilter('product_id', productIds)
        .order('created_at', ascending: false);

    // product_id → 가장 최신 scan (이미 내림차순이므로 첫 번째가 최신)
    final Map<String, Map<String, dynamic>> scanByProduct = {};
    for (final scan in (scanRows as List)) {
      final pid = scan['product_id'] as String?;
      if (pid != null && !scanByProduct.containsKey(pid)) {
        scanByProduct[pid] = Map<String, dynamic>.from(scan as Map);
      }
    }

    return cabinetRows.map<Map<String, dynamic>>((cabinet) {
      final productId = cabinet['product_id'] as String;
      final scan = scanByProduct[productId];
      final gemini = scan?['gemini_response'] as Map<String, dynamic>?;
      return {
        'cabinet_id': cabinet['id'] as String,
        'product_id': productId,
        'added_at': cabinet['created_at'] as String,
        'scan_id': scan?['id'] as String?,
        'image_url': scan?['raw_image_url'] as String?,
        'product_name': gemini?['product_name'] as String? ?? '알 수 없는 제품',
      };
    }).toList();
  }

  Future<void> deleteFromCabinet(String cabinetId) async {
    await _supabase.from('cabinet').delete().eq('id', cabinetId);
  }
}
