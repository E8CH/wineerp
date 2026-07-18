import 'package:flutter/material.dart';

/// wineerp 색 시스템 (UX 사양 v2 — 딥 네이비 + 화이트, 카테고리 컬러 바).
class AppColors {
  AppColors._();

  static const navy = Color(0xFF123E7C); // Primary — 헤더·주요 액션·[완료]
  static const navyStrong = Color(0xFF1766B0); // 강조 숫자·링크·차트
  static const container = Color(0xFFE4ECF7); // 현재고 배지·선택 칩
  static const background = Color(0xFFF6F7F9); // 쿨 그레이 배경
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1A1D21);
  static const muted = Color(0xFF7B828C);

  // 카테고리 컬러 바 (정보 위계)
  static const categoryIdentity = navy; // 식별
  static const categoryLabel = Color(0xFF9B1B1B); // 마룬 — 라벨·사진
  static const categoryStock = Color(0xFFB8860B); // 골드 — 재고·입고

  // 상태
  static const success = Color(0xFF2E7D53);
  static const warning = Color(0xFFB8860B);
  static const error = Color(0xFFD32F2F);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.navy,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    // 시인성 우선 큰 타이포 스케일 (폰트 번들은 후속 — 시스템 Noto Sans KR 사용)
    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.container,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
