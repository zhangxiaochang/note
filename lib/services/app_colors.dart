import 'package:flutter/material.dart';

/// 全局调色板（编译期常量，iOS grouped / Notes 风格）。
abstract final class AppThemeColors {
  static const Color primaryColor = Color(0xFF0A84FF);
  static const Color primaryColorDark = Color(0xFF409CFF);
  static const Color secondaryColor = Color(0xFF10B981);
  static const Color accentColor = Color(0xFF0A84FF);

  static const Color lightBackgroundColor = Color(0xFFF2F2F7);
  static const Color darkBackgroundColor = Color(0xFF000000);
  static const Color lightCardColor = Color(0xFFFFFFFF);
  static const Color darkCardColor = Color(0xFF1C1C1E);

  static const Color lightTextColor = Color(0xFF000000);
  static const Color darkTextColor = Color(0xFFFFFFFF);
  static const Color lightSecondaryTextColor = Color(0xFF8E8E93);
  static const Color darkSecondaryTextColor = Color(0xFF8E8E93);

  static const Color lightBorderColor = Color(0xFFE5E5EA);
  static const Color darkBorderColor = Color(0xFF38383A);

  static const Color categoryTagLightBg = Color(0xFFF2F2F7);
  static const Color categoryTagDarkBg = Color(0xFF3A3A3C);
}
