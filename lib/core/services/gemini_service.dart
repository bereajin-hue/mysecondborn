import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';

class GeminiService {
  final GenerativeModel _model;
  final String _prompt;

  static const _timeout = Duration(seconds: 10);

  // 규칙 3번: Exponential backoff 1s → 3s → 9s (3회 재시도)
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 9),
  ];

  // prompt를 외부에서 주입받는 이유: Flutter는 rootBundle, CLI는 File 로드 방식이 달라서
  GeminiService({required String apiKey, required String prompt})
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: apiKey,
        ),
        _prompt = prompt;

  /// 영양제 이미지를 분석해 JSON Map을 반환.
  /// 에러 시 한국어 메시지를 담은 [GeminiException] throw.
  Future<Map<String, dynamic>> analyzeProduct(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();

    // 규칙 6번: 5MB 초과는 앱 단에서 압축 후 호출해야 함
    if (imageBytes.lengthInBytes > AppConfig.maxImageBytes) {
      throw const GeminiException('이미지가 너무 큽니다. 앱에서 압축 후 다시 시도해주세요.');
    }

    final mimeType = _detectMimeType(imageFile.path);
    Object? lastError;

    for (int attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final response = await _model
            .generateContent([
              Content.multi([
                TextPart(_prompt),
                DataPart(mimeType, imageBytes),
              ])
            ])
            .timeout(_timeout);

        final text = response.text?.trim();
        if (text == null || text.isEmpty) {
          throw const FormatException('분석 결과가 비어있습니다');
        }

        return _parseAndValidate(text);
      } catch (e, s) {
        lastError = e;

        // CLI 환경(Sentry 미초기화)에서도 무중단으로 진행하기 위해 try-catch 래핑
        try {
          await Sentry.captureException(
            e,
            stackTrace: s,
            hint: Hint.withMap({'attempt': attempt.toString()}),
          );
        } catch (_) {}

        if (attempt < _retryDelays.length) {
          await Future.delayed(_retryDelays[attempt]);
        }
      }
    }

    // 모든 재시도 소진 후 유저에게 노출할 메시지 포장
    final isTimeout = lastError is TimeoutException;
    throw GeminiException(
      isTimeout
          ? '분석 시간이 너무 오래 걸렸어요. 잠시 후 다시 시도해주세요.'
          : '잠깐 문제가 생겼어요. 다시 시도해주세요.',
      cause: lastError,
    );
  }

  Map<String, dynamic> _parseAndValidate(String text) {
    // Gemini가 간혹 마크다운 코드블록을 포함하는 경우 방어 처리
    final cleaned = text
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '')
        .trim();

    final Map<String, dynamic> result;
    try {
      result = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      final preview = cleaned.length > 200 ? '${cleaned.substring(0, 200)}...' : cleaned;
      throw GeminiException('분석 결과를 읽을 수 없어요. 다시 시도해주세요.', cause: preview);
    }

    // 에러 응답은 검증 없이 통과 (영양제 아님 케이스)
    if (result.containsKey('error')) return result;

    // 필수 필드 검증
    for (final key in ['product_name', 'confidence', 'readable_summary']) {
      if (!result.containsKey(key) || result[key] == null) {
        throw GeminiException('분석 결과가 완전하지 않아요. 다시 시도해주세요.',
            cause: '필수 필드 누락: $key');
      }
    }

    // confidence 범위 검증
    final confidence = result['confidence'];
    if (confidence is! num || confidence < 0 || confidence > 1) {
      throw const GeminiException('분석 결과가 올바르지 않아요. 다시 시도해주세요.');
    }

    return result;
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

/// GeminiService 전용 예외 — 유저에게 노출할 한국어 메시지 포함
class GeminiException implements Exception {
  final String userMessage;
  final Object? cause;

  const GeminiException(this.userMessage, {this.cause});

  @override
  String toString() =>
      'GeminiException: $userMessage${cause != null ? ' (cause: $cause)' : ''}';
}
