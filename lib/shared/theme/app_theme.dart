import 'package:flutter/material.dart';

class AppTheme {
  // 파스텔 금지 — 시니어는 낮은 채도 색상을 구분하기 어려워서 높은 대비값 사용
  static const primaryColor = Color(0xFFFF6B35);
  static const backgroundColor = Color(0xFFFAFAFA);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      surface: backgroundColor,
    ),
    // 기본 18sp: 70대 기준 최소 가독성 — CLAUDE.md 규칙 7번
    textTheme: const TextTheme(
      bodySmall: TextStyle(fontSize: 16, color: Color(0xFF333333)),
      bodyMedium: TextStyle(fontSize: 18, color: Color(0xFF1A1A1A)),
      bodyLarge: TextStyle(fontSize: 20, color: Color(0xFF1A1A1A)),
      titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
    ),
    appBarTheme: const AppBarTheme(
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      backgroundColor: Color(0xFFFAFAFA),
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    // 버튼 최소 높이 56: 손가락이 굵은 어르신도 확실하게 탭 가능
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        animationDuration: const Duration(milliseconds: 100),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: Color(0xFF999999),
      selectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 16,
      titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFF1A1A1A)),
      subtitleTextStyle: TextStyle(fontSize: 15, color: Color(0xFF888888)),
    ),
    dividerTheme: const DividerThemeData(space: 0),
  );
}
