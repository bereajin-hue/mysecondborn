import 'package:flutter/material.dart';

// 시니어(70대) 대상 앱: 글씨 최소 16sp, 터치 영역 최소 48x48
class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
      bodyLarge: TextStyle(fontSize: 18),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );
}
