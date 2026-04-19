import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' show OAuthToken, UserApi, isKakaoTalkInstalled;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthRepository {
  final _supabase = Supabase.instance.client;

  // 규칙 3번: 외부 API 호출 — try-catch + exponential backoff 3회
  Future<void> signInWithKakao() async {
    Object? lastError;

    for (int attempt = 0; attempt <= 2; attempt++) {
      try {
        // 1) 카카오톡 앱 → 없으면 카카오 계정 웹 로그인 (웹 빌드 포함 대응)
        OAuthToken kakaoToken;
        if (await isKakaoTalkInstalled()) {
          kakaoToken = await UserApi.instance.loginWithKakaoTalk();
        } else {
          kakaoToken = await UserApi.instance.loginWithKakaoAccount();
        }

        // 2) Edge Function 호출 (카카오 토큰 검증 + Supabase 유저 생성/조회)
        final res = await _supabase.functions
            .invoke(
              'kakao-auth',
              body: {'access_token': kakaoToken.accessToken},
            )
            .timeout(const Duration(seconds: 10));

        // Edge Function이 400을 반환하면 error 필드가 있음
        if (res.data is Map && res.data['error'] != null) {
          throw Exception(res.data['error'] as String);
        }

        final email = res.data['email'] as String;
        final otp   = res.data['token'] as String;

        // 3) OTP 토큰으로 Supabase 세션 수립 — 성공하면 GoRouter가 /로 이동
        await _supabase.auth.verifyOTP(
          email: email,
          token: otp,
          type: OtpType.magiclink,
        );

        return; // 성공 → 루프 탈출
      } catch (e, s) {
        lastError = e;
        // CLI 환경(Sentry 미초기화) 무중단 처리
        try {
          await Sentry.captureException(
            e,
            stackTrace: s,
            hint: Hint.withMap({'attempt': attempt.toString()}),
          );
        } catch (_) {}

        if (attempt < 2) {
          await Future.delayed(Duration(seconds: attempt == 0 ? 1 : 3));
        }
      }
    }

    // 재시도 소진 — 유저에게 친절한 메시지
    throw AuthException(
      _toUserMessage(lastError),
      cause: lastError,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  // 기술적 예외를 유저 언어로 변환 — 금지어(Error/Failed/Exception) 사용 안 함
  String _toUserMessage(Object? error) {
    final msg = error?.toString() ?? '';
    if (msg.contains('network') || msg.contains('SocketException')) {
      return '인터넷 연결을 확인하고 다시 시도해주세요.';
    }
    if (msg.contains('카카오')) return msg;
    return '잠깐 문제가 생겼어요. 다시 시도해주세요.';
  }
}

class AuthException implements Exception {
  final String userMessage;
  final Object? cause;
  const AuthException(this.userMessage, {this.cause});

  @override
  String toString() => 'AuthException: $userMessage';
}
