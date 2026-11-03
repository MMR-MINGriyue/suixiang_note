import 'package:flutter/material.dart';

/// 随想随记 设计 Token —— 对齐《随想随记-UI-UX设计.md》§2.1
/// 风格：纸感工作台 × 水滴进度
class T {
  // 品牌与阶段色
  static const brandPrimary = Color(0xFF4C6FFF);
  static const brandPrimaryDark = Color(0xFF7B93FF);
  static const brandPressed = Color(0xFF3D5BE0);
  static const brandContainer = Color(0xFFE8EDFF);
  static const stageInspiration = Color(0xFFA8B9E6);
  static const stageInProgress = Color(0xFF4C6FFF);
  static const stageDone = Color(0xFF2FBF8F);

  // 表面与文字
  static const paperBg = Color(0xFFFAF7F2);
  static const paperCard = Color(0xFFFFFFFF);
  static const inkPrimary = Color(0xFF2B2F3A);
  static const inkSecondary = Color(0xFF6B7280);
  static const inkTertiary = Color(0xFF9CA3AF);

  // 深色
  static const darkBg = Color(0xFF1C1E26);
  static const darkCard = Color(0xFF262935);
  static const darkInkPrimary = Color(0xFFE8EAF2);
  static const darkInkSecondary = Color(0xFFA0A6B8);
  static const darkInkTertiary = Color(0xFF6E7488);

  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A623);
  static const dangerContainer = Color(0xFFFDECEC);
  static const darkDangerContainer = Color(0xFF3A2629);
  static const paperCardAlt = Color(0xFFF4F0E9);
  static const darkCardAlt = Color(0xFF2E3140);

  // 卡片单层浅投影（性能守则：每卡最多 1 层 BoxShadow，禁双层堆叠）
  static List<BoxShadow> shadowCard(Brightness b) => [
        BoxShadow(
          color: (b == Brightness.light ? Color(0xFF000000) : Color(0xFF000000))
              .withValues(alpha: b == Brightness.light ? 0.08 : 0.16),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // 圆角（卡片 18 / 弹层 24）
  static const rCard = 18.0;
  static const rSheet = 24.0;

  // 间距（4px 基准，页边距 16）
  static const pagePad = 16.0;
}

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: T.paperBg,
    colorScheme: base.colorScheme.copyWith(
      primary: T.brandPrimary,
      onPrimary: Colors.white,
      primaryContainer: T.brandContainer,
      secondary: T.stageDone,
      error: T.danger,
      surface: T.paperCard,
    ),
    cardTheme: CardThemeData(
      color: T.paperCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        side: BorderSide(color: T.inkPrimary.withValues(alpha: 0.06)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: T.paperCard,
      indicatorColor: T.brandContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? T.brandPrimary : T.inkSecondary)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? T.brandPrimary : T.inkSecondary)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.paperCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: T.inkPrimary.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: T.inkPrimary.withValues(alpha: 0.08)),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: T.darkBg,
    colorScheme: base.colorScheme.copyWith(
      primary: T.brandPrimaryDark,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF2E3554),
      secondary: const Color(0xFF3DD6A0),
      error: const Color(0xFFFF6B70),
      surface: T.darkCard,
    ),
    cardTheme: CardThemeData(
      color: T.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        side: BorderSide(color: T.darkInkPrimary.withValues(alpha: 0.08)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: T.darkCard,
      indicatorColor: const Color(0xFF2E3554),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color:
              states.contains(WidgetState.selected) ? T.brandPrimaryDark : T.darkInkSecondary)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? T.brandPrimaryDark : T.darkInkSecondary)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: T.darkInkPrimary.withValues(alpha: 0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: T.darkInkPrimary.withValues(alpha: 0.10)),
      ),
    ),
  );
}
