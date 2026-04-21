import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
        ),
        _prompt = prompt;

  /// 웹·모바일 공용 — XFile.readAsBytes() 결과를 그대로 받아서 분석
  Future<Map<String, dynamic>> analyzeBytes(Uint8List bytes, String mimeType) async {
    if (bytes.lengthInBytes > AppConfig.maxImageBytes) {
      throw const GeminiException('이미지가 너무 큽니다. 앱에서 압축 후 다시 시도해주세요.');
    }
    return _analyze(DataPart(mimeType, bytes));
  }

  Future<Map<String, dynamic>> _analyze(DataPart dataPart) async {
    Object? lastError;

    for (int attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final response = await _model
            .generateContent([
              Content.multi([TextPart(_prompt), dataPart])
            ])
            .timeout(_timeout);

        final text = response.text?.trim();
        if (text == null || text.isEmpty) {
          throw const FormatException('분석 결과가 비어있습니다');
        }

        return _parseAndValidate(text);
      } catch (e, s) {
        lastError = e;
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

    final isTimeout = lastError is TimeoutException;
    throw GeminiException(
      isTimeout
          ? '분석 시간이 너무 오래 걸렸어요. 잠시 후 다시 시도해주세요.'
          : '잠깐 문제가 생겼어요. 다시 시도해주세요.',
      cause: lastError,
    );
  }

  Map<String, dynamic> _parseAndValidate(String text) {
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

    if (result.containsKey('error')) return result;

    for (final key in ['product_name', 'confidence', 'readable_summary']) {
      if (!result.containsKey(key) || result[key] == null) {
        throw GeminiException('분석 결과가 완전하지 않아요. 다시 시도해주세요.',
            cause: '필수 필드 누락: $key');
      }
    }

    final confidence = result['confidence'];
    if (confidence is! num || confidence < 0 || confidence > 1) {
      throw const GeminiException('분석 결과가 올바르지 않아요. 다시 시도해주세요.');
    }

    return result;
  }

}

class GeminiException implements Exception {
  final String userMessage;
  final Object? cause;

  const GeminiException(this.userMessage, {this.cause});

  @override
  String toString() =>
      'GeminiException: $userMessage${cause != null ? ' (cause: $cause)' : ''}';
}
