import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 앱 전역 auth 상태 단일 진입점 — 여러 곳에서 ref.watch로 구독
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// 스트림 구독 전 초기값으로 Supabase 캐시를 읽어 로그인 화면 깜빡임 방지
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
});
