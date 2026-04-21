import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/login_screen.dart';
import 'features/cabinet/cabinet_screen.dart';
import 'features/scan/home_screen.dart';
import 'features/scan/result_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/config/prefs_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/error_boundary.dart';

// 오프라인 여부를 bool로 emit — true면 오프라인
final connectivityProvider = StreamProvider<bool>((ref) async* {
  bool _offline(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((e) => e == ConnectivityResult.none);

  try {
    final initial = await Connectivity().checkConnectivity();
    yield _offline(initial);
  } catch (_) {
    yield false;
  }

  await for (final results in Connectivity().onConnectivityChanged) {
    yield _offline(results);
  }
});

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
          builder: (context, state, shell) => ErrorBoundary(
            builder: (_) => _AppShell(shell: shell),
          ),
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
          builder: (context, state) => ErrorBoundary(
            builder: (_) => ResultScreen(
              scanId: state.pathParameters['scanId'] ?? '',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontSizeProvider.select((l) => l.scale));

    return MaterialApp.router(
      title: 'MomPill',
      theme: AppTheme.light,
      routerConfig: _router,
      // 글씨 크기 설정값을 앱 전체에 반영 — 시니어 설정에서 선택한 배율 적용
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale),
        ),
        child: child!,
      ),
    );
  }
}

// 하단 탭 네비게이션 — 스와이프 없음, 탭 3개
class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(connectivityProvider).maybeWhen(
      data: (offline) => offline,
      orElse: () => false,
    );

    // 오프라인 → 온라인 복귀 시 Supabase Realtime 재연결
    ref.listen(connectivityProvider, (prev, next) {
      final wasOffline =
          prev?.maybeWhen(data: (o) => o, orElse: () => false) ?? false;
      final nowOnline =
          next.maybeWhen(data: (o) => !o, orElse: () => false);
      if (wasOffline && nowOnline) {
        try {
          Supabase.instance.client.realtime.connect();
        } catch (_) {}
      }
    });

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isOffline
                ? const _OfflineBanner()
                : const SizedBox.shrink(),
          ),
          Expanded(child: widget.shell),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.shell.currentIndex,
        // initialLocation: true → 같은 탭 재탭 시 해당 탭의 루트로 돌아가는 동작
        onTap: (index) => widget.shell.goBranch(
          index,
          initialLocation: index == widget.shell.currentIndex,
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF333333),
      padding: EdgeInsets.fromLTRB(
        16,
        // 상태바 높이만큼 상단 패딩 추가
        MediaQuery.of(context).padding.top + 10,
        16,
        10,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 18),
          SizedBox(width: 8),
          Text(
            '인터넷 연결을 확인해주세요',
            style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500),
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
