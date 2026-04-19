import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/login_screen.dart';
import 'features/cabinet/cabinet_screen.dart';
import 'features/scan/home_screen.dart';
import 'features/scan/result_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/theme/app_theme.dart';

class MomPillApp extends ConsumerStatefulWidget {
  const MomPillApp({super.key});

  @override
  ConsumerState<MomPillApp> createState() => _MomPillAppState();
}

class _MomPillAppState extends ConsumerState<MomPillApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // auth 스트림 변화 시 GoRouter가 즉시 redirect를 재평가하도록 연결
    // — 로그아웃 직후 /login으로 이동하려면 이 연결이 반드시 필요
    final refreshListenable = _AuthChangeNotifier(
      Supabase.instance.client.auth.onAuthStateChange,
    );

    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        final user = Supabase.instance.client.auth.currentUser;
        final isLoginRoute = state.matchedLocation == '/login';
        if (user == null && !isLoginRoute) return '/login';
        if (user != null && isLoginRoute) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        // 하단 탭 3개를 공유하는 셸 라우트
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/cabinet',
                builder: (context, state) => const CabinetScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ]),
          ],
        ),
        // 결과 화면은 전체 화면으로 표시 (탭바 없음)
        GoRoute(
          path: '/result/:scanId',
          builder: (context, state) => ResultScreen(
            scanId: state.pathParameters['scanId'] ?? '',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MomPill',
      theme: AppTheme.light,
      routerConfig: _router,
      // 전환 애니메이션 최소화 — 시니어는 갑작스러운 화면 전환에 혼란을 느낄 수 있음
      builder: (context, child) => child!,
    );
  }
}

// 하단 탭 네비게이션 — 스와이프 없음, 탭 3개
class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        // initialLocation: true → 같은 탭 재탭 시 해당 탭의 루트로 돌아가는 동작
        onTap: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt_rounded),
            label: '사진 분석',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined),
            activeIcon: Icon(Icons.medication_rounded),
            label: '내 영양제',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

// ChangeNotifier로 auth 스트림을 GoRouter refreshListenable에 연결
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Stream<AuthState> stream) {
    stream.listen((_) => notifyListeners());
  }
}
