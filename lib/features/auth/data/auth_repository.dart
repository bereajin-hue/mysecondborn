import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/env.dart';

class AuthRepository {
  final _supabase = Supabase.instance.client;

  // gotrue 패키지가 웹에서 Kakao JS SDK를 직접 호출하는 문제 우회
  // url_launcher로 Supabase auth URL을 직접 열어 서버사이드 OAuth 강제
  Future<void> signInWithKakao() async {
    try {
      if (kIsWeb) {
        final redirectTo = Uri.base.origin;
        final authUri = Uri.parse(Env.supabaseUrl).replace(
          path: '/auth/v1/authorize',
          queryParameters: {'provider': 'kakao', 'redirect_to': redirectTo},
        );
        await launchUrl(authUri, mode: LaunchMode.platformDefault);
      } else {
        await _supabase.auth.signInWithOAuth(OAuthProvider.kakao);
      }
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

