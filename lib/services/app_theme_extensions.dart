import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 首页底部「液态玻璃」导航条专用色（由 [ThemeData.extensions] 注入）。
@immutable
class AppGlassNavBarTheme extends ThemeExtension<AppGlassNavBarTheme> {
  const AppGlassNavBarTheme({
    required this.barShadow,
    required this.barBorder,
    required this.barFill,
    required this.selectionPill,
    required this.navSelected,
    required this.navUnselected,
  });

  /// 与 [Theme.of] 对称：从当前主题取扩展；缺失时回退到浅色玻璃。
  static AppGlassNavBarTheme of(BuildContext context) {
    return Theme.of(context).extension<AppGlassNavBarTheme>() ??
        AppGlassNavBarTheme.light;
  }

  final Color barShadow;
  final Color barBorder;
  final Color barFill;
  final Color selectionPill;
  final Color navSelected;
  final Color navUnselected;

  static const AppGlassNavBarTheme light = AppGlassNavBarTheme(
    barShadow: Color(0x14000000),
    barBorder: Color(0x0F000000),
    barFill: Color(0x73FFFFFF),
    selectionPill: Color(0x0E000000),
    navSelected: AppThemeColors.lightTextColor,
    navUnselected: AppThemeColors.lightSecondaryTextColor,
  );

  static const AppGlassNavBarTheme dark = AppGlassNavBarTheme(
    barShadow: Color(0x6B000000),
    barBorder: Color(0x2EFFFFFF),
    barFill: Color(0x14FFFFFF),
    selectionPill: Color(0x24FFFFFF),
    navSelected: AppThemeColors.darkTextColor,
    navUnselected: AppThemeColors.darkSecondaryTextColor,
  );

  @override
  AppGlassNavBarTheme copyWith({
    Color? barShadow,
    Color? barBorder,
    Color? barFill,
    Color? selectionPill,
    Color? navSelected,
    Color? navUnselected,
  }) {
    return AppGlassNavBarTheme(
      barShadow: barShadow ?? this.barShadow,
      barBorder: barBorder ?? this.barBorder,
      barFill: barFill ?? this.barFill,
      selectionPill: selectionPill ?? this.selectionPill,
      navSelected: navSelected ?? this.navSelected,
      navUnselected: navUnselected ?? this.navUnselected,
    );
  }

  @override
  AppGlassNavBarTheme lerp(AppGlassNavBarTheme? other, double t) {
    if (other is! AppGlassNavBarTheme) return this;
    return AppGlassNavBarTheme(
      barShadow: Color.lerp(barShadow, other.barShadow, t)!,
      barBorder: Color.lerp(barBorder, other.barBorder, t)!,
      barFill: Color.lerp(barFill, other.barFill, t)!,
      selectionPill: Color.lerp(selectionPill, other.selectionPill, t)!,
      navSelected: Color.lerp(navSelected, other.navSelected, t)!,
      navUnselected: Color.lerp(navUnselected, other.navUnselected, t)!,
    );
  }
}
