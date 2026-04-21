import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthRepository {
  final _supabase = Supabase.instance.client;

  // 웹 MVP: kakao_flutter_sdk는 웹 미지원 → Supabase 내장 Kakao OAuth 사용
  // 모바일 추가 시 kIsWeb 분기로 기존 SDK 방식 복구 가능
  Future<void> signInWithKakao() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
      );
    } catch (e, s) {
      try {
        await Sentry.captureException(e, stackTrace: s);
      } catch (_) {}
      throw AuthException('잠깐 문제가 생겼어요. 다시 시도해주세요.', cause: e);
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
}

class AuthException implements Exception {
  final String userMessage;
  final Object? cause;
  const AuthException(this.userMessage, {this.cause});

  @override
  String toString() => 'AuthException: $userMessage';
}

