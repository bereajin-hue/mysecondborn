/// Gemini 영양제 분석 CLI 테스트 도구
///
/// 사용법:
///   dart run tool/test_gemini.dart <이미지_파일_경로>
///
/// 예시:
///   dart run tool/test_gemini.dart ~/Downloads/vitamin_c.jpg
///
/// 전제조건:
///   - 프로젝트 루트에 .env 파일이 있고 GEMINI_API_KEY 값이 설정되어 있어야 함
///   - prompts/product_analysis.md 파일이 존재해야 함

import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _err('사용법: dart run tool/test_gemini.dart <이미지_파일_경로>');
    exit(1);
  }

  // ── 환경변수 로드 ──────────────────────────────────────────
  final apiKey = _loadEnvKey('GEMINI_API_KEY');
  if (apiKey == null) {
    _err('.env 파일에 GEMINI_API_KEY가 없습니다. .env.example을 참고하세요.');
    exit(1);
  }

  // ── 이미지 파일 확인 ───────────────────────────────────────
  final imageFile = File(args[0]);
  if (!imageFile.existsSync()) {
    _err('이미지 파일을 찾을 수 없습니다: ${args[0]}');
    exit(1);
  }

  final imageBytes = imageFile.readAsBytesSync();
  final fileSizeMb = imageBytes.lengthInBytes / (1024 * 1024);
  if (fileSizeMb > 5.0) {
    _err('이미지 크기가 5MB를 초과합니다 (${fileSizeMb.toStringAsFixed(1)}MB). 압축 후 재시도하세요.');
    exit(1);
  }

  // ── 프롬프트 로드 ──────────────────────────────────────────
  final promptFile = File('prompts/product_analysis.md');
  if (!promptFile.existsSync()) {
    _err('프롬프트 파일이 없습니다: prompts/product_analysis.md');
    exit(1);
  }
  final prompt = promptFile.readAsStringSync();

  // ── Gemini 호출 ────────────────────────────────────────────
  stdout.writeln('📸 분석 중... (${args[0]}, ${fileSizeMb.toStringAsFixed(2)}MB)');

  final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
  final mimeType = _detectMimeType(args[0]);

  // 재시도 로직: 1s → 3s → 9s (규칙 3번)
  final retryDelays = [
    const Duration(seconds: 1),
    const Duration(seconds: 3),
    const Duration(seconds: 9),
  ];

  Object? lastError;
  for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
    if (attempt > 0) {
      stdout.writeln('  재시도 $attempt/3 (${retryDelays[attempt - 1].inSeconds}초 대기 후)...');
    }
    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ])
      ]).timeout(const Duration(seconds: 10));

      final raw = response.text?.trim() ?? '';
      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'```\s*', multiLine: true), '')
          .trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      // ── 결과 출력 ──────────────────────────────────────────
      stdout.writeln('\n✅ 분석 완료\n');

      if (json.containsKey('error')) {
        stdout.writeln('⚠️  ${json['error']}');
        return;
      }

      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
      final confidenceBar = _confidenceBar(confidence);

      stdout.writeln('제품명    : ${json['product_name'] ?? '-'}');
      stdout.writeln('브랜드    : ${json['brand'] ?? '-'}');
      stdout.writeln('카테고리  : ${json['category'] ?? '-'}');
      stdout.writeln('추천 연령 : ${json['target_age'] ?? '-'}');
      stdout.writeln('신뢰도    : $confidenceBar (${(confidence * 100).round()}%)');

      final ingredients = json['main_ingredients'] as List<dynamic>? ?? [];
      if (ingredients.isNotEmpty) {
        stdout.writeln('\n주요 성분:');
        for (final ing in ingredients) {
          final i = ing as Map<String, dynamic>;
          final daily = i['daily_percent'] != null ? '  (일일권장량 ${i['daily_percent']})' : '';
          stdout.writeln('  · ${i['name']}  ${i['amount'] ?? ''}$daily');
        }
      }

      final benefits = json['key_benefits'] as List<dynamic>? ?? [];
      if (benefits.isNotEmpty) {
        stdout.writeln('\n주요 효능:');
        for (final b in benefits) stdout.writeln('  · $b');
      }

      final warnings = json['warnings'] as List<dynamic>? ?? [];
      if (warnings.isNotEmpty) {
        stdout.writeln('\n주의사항:');
        for (final w in warnings) stdout.writeln('  ⚠ $w');
      }

      stdout.writeln('\n💬 요약:\n${json['readable_summary'] ?? '-'}');
      stdout.writeln('\n── Raw JSON ──────────────────────────────────');
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(json));
      return;
    } catch (e) {
      lastError = e;
      if (attempt < retryDelays.length) {
        await Future.delayed(retryDelays[attempt]);
      }
    }
  }

  _err('\n❌ 분석 실패 (3회 재시도 소진): $lastError');
  exit(1);
}

String _detectMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _confidenceBar(double v) {
  final filled = (v * 10).round().clamp(0, 10);
  return '[${'█' * filled}${'░' * (10 - filled)}]';
}

void _err(String msg) => stderr.writeln(msg);

/// .env 파일에서 특정 키의 값을 읽음 (flutter_dotenv 없이 CLI에서 직접 사용)
String? _loadEnvKey(String key) {
  final envFile = File('.env');
  if (!envFile.existsSync()) return null;
  for (final line in envFile.readAsLinesSync()) {
    if (line.startsWith('#') || !line.contains('=')) continue;
    final eq = line.indexOf('=');
    if (line.substring(0, eq).trim() == key) {
      return line.substring(eq + 1).trim();
    }
  }
  return null;
}
