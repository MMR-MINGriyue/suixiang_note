import 'package:flutter/material.dart';

/// 随想随记 设计 Token —— 对齐《随想随记-UI-UX设计.md》§2
/// 风格：纸感工作台 × 水滴进度
///
/// v2.3 主题层补全：把「字号层级 / 组件默认外观」收进 ThemeData。
/// 之前每个页面都在手写 `TextStyle(fontSize: 11, color: T.inkTertiary)`，
/// 既重复又漏判深色模式；现在一处改主题，所有页面跟着走。
class T {
  // 品牌与阶段色
  static const brandPrimary = Color(0xFF4C6FFF);
  static const brandPrimaryDark = Color(0xFF7B93FF);
  static const brandPressed = Color(0xFF3D5BE0);
  static const brandContainer = Color(0xFFE8EDFF);
  static const stageInspiration = Color(0xFFA8B9E6);
  static const stageInProgress = Color(0xFF4C6FFF);
  static const stageDone = Color(0xFF2FBF8F);

  // 表面与文字（浅色）
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

  /// 语义墨色：按当前主题亮度自动取对应文字色。
  ///
  /// 页面里凡「次要 / 辅助」文字都走这两个。直接写 `T.inkSecondary`
  /// 在深色底上对比度只有 2.8:1（远低于 WCAG 4.5:1），是 v2.3 之前
  /// 深色模式最普遍的视觉缺陷。
  ///
  /// `...Of(bool dark)` 给只持有亮度标志、拿不到 context 的底层组件用；
  /// `... (BuildContext)` 是页面层的快捷入口，二者结果恒一致。
  static Color ink1Of(bool dark) => dark ? darkInkPrimary : inkPrimary;

  static Color ink2Of(bool dark) => dark ? darkInkSecondary : inkSecondary;

  static Color ink3Of(bool dark) => dark ? darkInkTertiary : inkTertiary;

  static Color ink1(BuildContext context) =>
      ink1Of(Theme.of(context).brightness == Brightness.dark);

  static Color ink2(BuildContext context) =>
      ink2Of(Theme.of(context).brightness == Brightness.dark);

  static Color ink3(BuildContext context) =>
      ink3Of(Theme.of(context).brightness == Brightness.dark);

  /// 语义表面：卡片 / 次级容器 / 页面底，按亮度自动切换。
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : paperCard;

  static Color surfaceAlt(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardAlt
          : paperCardAlt;

  static Color pageBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : paperBg;

  // 卡片单层浅投影（性能守则：每卡最多 1 层 BoxShadow，禁双层堆叠）
  static List<BoxShadow> shadowCard(Brightness b) => [
        BoxShadow(
          color: const Color(0xFF000000)
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

/// 九级字阶（对齐 UI-UX 设计 §2.3）：靠「色阶 > 字重 > 留白 > 字号」分层次，
/// 不靠一味放大字号。行高统一给足，中文长文不挤。
TextTheme _textTheme(Color primary, Color secondary, Color tertiary) => TextTheme(
      displayLarge: TextStyle(
          fontSize: 28, height: 1.25, fontWeight: FontWeight.w700, color: primary),
      displayMedium: TextStyle(
          fontSize: 24, height: 1.3, fontWeight: FontWeight.w700, color: primary),
      titleLarge: TextStyle(
          fontSize: 20, height: 1.35, fontWeight: FontWeight.w600, color: primary),
      titleMedium: TextStyle(
          fontSize: 16, height: 1.45, fontWeight: FontWeight.w600, color: primary),
      titleSmall: TextStyle(
          fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: primary),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: primary),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: secondary),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelSmall: TextStyle(
          fontSize: 10, height: 1.4, fontWeight: FontWeight.w500, color: tertiary),
    );

/// 通用组件主题：所有页面共享，避免每个页面各自手写一遍。
ThemeData _decorate(ThemeData base,
    {required Color bg,
    required Color card,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color brand,
    required Color brandContainer,
    required Color onBrand,
    required Color error,
    required Color surfaceTint}) {
  final hairline = primary.withValues(alpha: 0.08);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: _textTheme(primary, secondary, tertiary),
    colorScheme: base.colorScheme.copyWith(
      primary: brand,
      onPrimary: onBrand,
      primaryContainer: brandContainer,
      secondary: T.stageDone,
      error: error,
      surface: card,
      onSurface: primary,
      onSurfaceVariant: secondary,
      outline: hairline,
      outlineVariant: primary.withValues(alpha: 0.12),
      surfaceTint: surfaceTint,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        side: BorderSide(color: hairline),
      ),
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: secondary, size: 20),
    listTileTheme: ListTileThemeData(
      iconColor: secondary,
      textColor: primary,
      titleTextStyle:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primary),
      subtitleTextStyle: TextStyle(fontSize: 12, color: tertiary),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: primary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brandContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? brand : secondary)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? brand : secondary)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        borderSide: BorderSide(color: brand, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: onBrand,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        side: BorderSide(color: brand.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: brand),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: primary,
      contentTextStyle: TextStyle(fontSize: 13, color: card),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(T.rSheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, color: primary),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rCard)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(fontSize: 11, color: card),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: brand),
  );
}

ThemeData buildLightTheme() => _decorate(
      ThemeData.light(useMaterial3: true),
      bg: T.paperBg,
      card: T.paperCard,
      primary: T.inkPrimary,
      secondary: T.inkSecondary,
      tertiary: T.inkTertiary,
      brand: T.brandPrimary,
      brandContainer: T.brandContainer,
      onBrand: Colors.white,
      error: T.danger,
      surfaceTint: Colors.transparent,
    );

ThemeData buildDarkTheme() => _decorate(
      ThemeData.dark(useMaterial3: true),
      bg: T.darkBg,
      card: T.darkCard,
      primary: T.darkInkPrimary,
      secondary: T.darkInkSecondary,
      tertiary: T.darkInkTertiary,
      brand: T.brandPrimaryDark,
      brandContainer: const Color(0xFF2E3554),
      onBrand: Colors.white,
      error: const Color(0xFFFF6B70),
      surfaceTint: Colors.transparent,
    );
