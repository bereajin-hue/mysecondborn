import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

// Day 3에서 실제 카카오 SDK 연결 — 지금은 버튼 뼈대만
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'MomPill',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '영양제 사기 전에\n사진 한 장 찍어보세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Color(0xFF555555), height: 1.5),
              ),
              const SizedBox(height: 80),
              // 카카오 노란색 버튼 — 카카오 브랜드 가이드라인 준수
              ElevatedButton(
                onPressed: null, // TODO Day 3: KakaoSdk 로그인 구현
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: const Color(0xFF191919),
                  disabledBackgroundColor: const Color(0xFFFEE500).withOpacity(0.6),
                ),
                child: const Text('카카오로 시작하기'),
              ),
              const SizedBox(height: 40),
              const Text(
                '무료 앱 · 광고 없음',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
