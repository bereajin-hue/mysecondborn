import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'data/auth_repository.dart';

export 'data/auth_repository.dart' show AuthRepository, AuthException;

// 앱 전역 auth 상태 단일 진입점 — 여러 곳에서 ref.watch로 구독
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// 스트림 구독 전 Supabase 캐시에서 즉시 읽어 로그인 화면 깜빡임 방지
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
});

// Repository 싱글턴 — 앱 생명주기 동안 하나만 유지
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// 로그인 버튼 로딩 상태 — UI에서 스피너 표시 용도
final loginLoadingProvider = StateProvider<bool>((ref) => false);

// 로그인 에러 메시지 — null이면 에러 없음
final loginErrorProvider = StateProvider<String?>((ref) => null);
