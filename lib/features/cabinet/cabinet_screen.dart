import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

// Day 4에서 Supabase cabinet 테이블 조회로 실제 목록 구현
class CabinetScreen extends StatelessWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('내 영양제')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 88,
              color: Color(0xFFDDDDDD),
            ),
            SizedBox(height: 24),
            Text(
              '아직 저장된 영양제가 없어요',
              style: TextStyle(fontSize: 20, color: Color(0xFF888888)),
            ),
            SizedBox(height: 12),
            Text(
              '영양제를 사진으로 찍으면\n자동으로 여기에 저장돼요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFFAAAAAA), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
