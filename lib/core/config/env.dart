import 'package:flutter_dotenv/flutter_dotenv.dart';

// dart-define 대신 flutter_dotenv 사용 — CI/CD와 로컬 개발 환경을 동일하게 관리하기 위해
class Env {
  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');
  static String get geminiApiKey => _require('GEMINI_API_KEY');
  static String get sentryDsn => _require('SENTRY_DSN');
  static String get kakaoNativeKey => _require('KAKAO_NATIVE_KEY');
  static String get coupangTrackingId => _require('COUPANG_TRACKING_ID');
  static String get postHogApiKey => dotenv.env['POSTHOG_API_KEY'] ?? '';

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      // 개발 시 빠르게 누락을 인지하기 위해 상세 메시지 허용
      throw StateError('.env에 $key 가 없습니다. .env.example을 참고하세요.');
    }
    return value;
  }
}
