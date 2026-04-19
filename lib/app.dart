import 'package:flutter/material.dart';
import 'shared/theme/app_theme.dart';

class MomPillApp extends StatelessWidget {
  const MomPillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MomPill',
      theme: AppTheme.light,
      // TODO: GoRouter 설정 (auth/ scan/ cabinet/ settings/ 라우트)
      home: const Scaffold(body: Center(child: Text('MomPill'))),
    );
  }
}
