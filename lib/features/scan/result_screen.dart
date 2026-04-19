import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';

// Day 3에서 실제 Gemini 분석 + Supabase 저장 구현
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.scanId});

  final String scanId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('분석 결과'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '뒤로',
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 5,
              ),
            ),
            SizedBox(height: 32),
            Text(
              '열심히 분석 중이에요...',
              style: TextStyle(fontSize: 20, color: Color(0xFF555555)),
            ),
            SizedBox(height: 12),
            Text(
              '잠깐만 기다려 주세요',
              style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}
