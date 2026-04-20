import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../theme/app_theme.dart';

// main.dart에서 한 번 호출 — Flutter 기본 빨간 화면 대신 친절한 UI로 교체
void setupGlobalErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppTheme.backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.sentiment_dissatisfied_rounded,
                    size: 72, color: Color(0xFFCCCCCC)),
                SizedBox(height: 24),
                Text(
                  '문제가 생겼어요',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333)),
                ),
                SizedBox(height: 12),
                Text(
                  '잠깐 문제가 생겼어요.\n앱을 다시 시작해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17, color: Color(0xFF666666), height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
}

// 화면별 에러 경계 — reportError() 호출 시 친절한 폴백 화면으로 전환,
// 재시도 버튼으로 자식 위젯 트리를 새 키로 재빌드
class ErrorBoundary extends StatefulWidget {
  final WidgetBuilder builder;
  const ErrorBoundary({super.key, required this.builder});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();

  static _ErrorBoundaryState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ErrorBoundaryScope>()
        ?.state;
  }
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Key _childKey = UniqueKey();
  bool _hasError = false;

  void reportError(Object error) {
    if (!mounted) return;
    try {
      Sentry.captureException(error);
    } catch (_) {}
    setState(() => _hasError = true);
  }

  void retry() {
    setState(() {
      _hasError = false;
      _childKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorFallbackScreen(onRetry: retry);
    }
    return _ErrorBoundaryScope(
      state: this,
      child: KeyedSubtree(
        key: _childKey,
        child: widget.builder(context),
      ),
    );
  }
}

class _ErrorBoundaryScope extends InheritedWidget {
  final _ErrorBoundaryState state;
  const _ErrorBoundaryScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(_ErrorBoundaryScope old) => false;
}

class _ErrorFallbackScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorFallbackScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sentiment_dissatisfied_rounded,
                    size: 88, color: Color(0xFFCCCCCC)),
                const SizedBox(height: 28),
                const Text(
                  '문제가 생겼어요',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333)),
                ),
                const SizedBox(height: 14),
                const Text(
                  '잠깐 문제가 생겼어요.\n다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, color: Color(0xFF666666), height: 1.6),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 24),
                    label: const Text(
                      '다시 시도',
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
