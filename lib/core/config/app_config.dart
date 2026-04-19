// 환경변수는 dart-define으로 주입 - 소스에 절대 키 하드코딩 금지
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const kakaoNativeKey = String.fromEnvironment('KAKAO_NATIVE_KEY');
  static const coupangTrackingId = String.fromEnvironment('COUPANG_TRACKING_ID');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  // 이미지 제약: Gemini 비용 폭주 방지
  static const int maxImageBytes = 5 * 1024 * 1024; // 5MB
  static const int maxImageDimension = 1024;

  // Gemini 호출 제한: 유저당 하루 소진 방지
  static const int geminiDailyLimit = 20;
}
