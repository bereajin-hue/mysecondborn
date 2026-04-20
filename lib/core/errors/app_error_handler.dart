// 유저에게 보이는 메시지와 개발자용 로그를 분리하기 위해 별도 파일로 관리
enum AppError {
  networkError,
  apiError,
  authError,
  unknownError,
  quotaExceeded,
  invalidImage,
}

extension AppErrorMessage on AppError {
  String get message {
    switch (this) {
      case AppError.networkError:
        return '인터넷 연결을 확인해주세요.';
      case AppError.apiError:
        return '잠깐 문제가 생겼어요. 다시 시도해주세요.';
      case AppError.authError:
        return '로그인이 필요해요. 다시 로그인해주세요.';
      case AppError.unknownError:
        return '잠깐 문제가 생겼어요. 다시 시도해주세요.';
      case AppError.quotaExceeded:
        return '오늘 분석 횟수를 모두 사용했어요. 내일 다시 시도해주세요.';
      case AppError.invalidImage:
        return '사진을 인식할 수 없어요. 다른 사진으로 시도해주세요.';
    }
  }
}

class AppException implements Exception {
  final AppError type;
  const AppException(this.type);

  @override
  String toString() => type.message;
}

class AppErrorHandler {
  // "Error", "500", "Exception", "Failed" 같은 기술 용어 절대 노출 금지
  static String toUserMessage(Object error) {
    if (error is AppException) return error.type.message;
    return classifyError(error).message;
  }

  static String toNetworkMessage() => AppError.networkError.message;
  static String toRateLimitMessage() => AppError.quotaExceeded.message;
}

// 예외 내용으로 AppError 종류를 추론
AppError classifyError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('인터넷')) {
    return AppError.networkError;
  }
  if (msg.contains('quota') ||
      msg.contains('limit') ||
      msg.contains('횟수')) {
    return AppError.quotaExceeded;
  }
  if (msg.contains('auth') ||
      msg.contains('unauthorized') ||
      msg.contains('로그인')) {
    return AppError.authError;
  }
  if (msg.contains('image') ||
      msg.contains('사진') ||
      msg.contains('invalid')) {
    return AppError.invalidImage;
  }
  return AppError.unknownError;
}
