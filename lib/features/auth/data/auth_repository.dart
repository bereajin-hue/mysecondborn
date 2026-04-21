import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthRepository {
  final _supabase = Supabase.instance.client;

  // 웹 MVP: kakao_flutter_sdk는 웹 미지원 → Supabase 내장 Kakao OAuth 사용
  // redirectTo 없으면 OAuth 콜백 후 앱으로 돌아오지 못함
  Future<void> signInWithKakao() async {
    try {
      final redirectTo = kIsWeb ? Uri.base.origin : null;
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: redirectTo,
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

