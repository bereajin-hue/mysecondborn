import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('설정')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // 글씨 크기 — 시니어가 더 크게 조절할 수 있도록 (Day 4 구현)
            ListTile(
              leading: const Icon(Icons.text_fields_rounded, color: AppTheme.primaryColor),
              title: const Text('글씨 크기'),
              subtitle: const Text('기본'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {}, // TODO Day 4
            ),
            const Divider(),
            // 앱 버전 — 고객센터 문의 시 필요
            const ListTile(
              leading: Icon(Icons.info_outline_rounded, color: Color(0xFF999999)),
              title: Text('버전'),
              trailing: Text(
                '0.1.0',
                style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
              ),
            ),
            const Spacer(),
            // 로그아웃 하단 배치 — 실수로 누르기 어려운 위치, 빨간색으로 위험 행동 표시
            ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text(
                      '로그아웃 하시겠어요?',
                      style: TextStyle(fontSize: 18),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소', style: TextStyle(fontSize: 16)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Supabase.instance.client.auth.signOut();
                  // GoRouter refreshListenable이 auth 변화를 감지해 /login으로 자동 이동
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('로그아웃'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
