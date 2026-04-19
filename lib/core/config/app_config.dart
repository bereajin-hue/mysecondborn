// Env 클래스에서 실제 값을 읽고, 여기서는 앱 전역 상수만 정의
class AppConfig {
  // 이미지 제약: Gemini 비용 폭주 방지
  static const int maxImageBytes = 5 * 1024 * 1024;
  static const int maxImageDimension = 1024;

  // Gemini 호출 제한: 유저당 하루 소진 방지
  static const int geminiDailyLimit = 20;
}
