// 유저에게 보이는 메시지와 개발자용 로그를 분리하기 위해 별도 파일로 관리
class AppErrorHandler {
  static String toUserMessage(Object error) {
    // "Error", "500", "Exception", "Failed" 같은 기술 용어 절대 노출 금지
    return '잠깐 문제가 생겼어요. 다시 시도해주세요.';
  }

  static String toNetworkMessage() {
    return '인터넷 연결을 확인하고 다시 시도해주세요.';
  }

  static String toRateLimitMessage() {
    return '오늘 분석 횟수를 모두 사용했어요. 내일 다시 시도해주세요.';
  }
}
