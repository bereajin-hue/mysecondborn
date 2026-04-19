import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../../shared/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // 카카오 로그인 전까지는 메타데이터 없으므로 기본값 처리
    final name = user?.userMetadata?['nickname'] as String? ?? '고객';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('안녕하세요, $name님 👋'),
        centerTitle: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '분석할 영양제를\n사진으로 찍어주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Color(0xFF555555), height: 1.5),
            ),
            const SizedBox(height: 56),
            // 지름 200px — 70대 어머니가 화면을 보자마자 눌러야 할 버튼이 명확해야 함
            GestureDetector(
              onTap: () => context.push('/result/new'),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 88,
                ),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              '버튼을 눌러 촬영하세요',
              style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}
