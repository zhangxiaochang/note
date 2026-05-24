import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'app_theme_extensions.dart';

export 'app_colors.dart';
export 'app_theme_extensions.dart';

enum ThemeModeOption { light, dark, system }
enum ViewModeOption { card, list }

/// 主题模式与列表视图偏好；持久化到 [SharedPreferences]，并生成 [ThemeData]。
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _viewModeKey = 'view_mode';

  ThemeModeOption _themeMode = ThemeModeOption.system;
  ViewModeOption _viewMode = ViewModeOption.card;

  ThemeModeOption get themeMode => _themeMode;
  ViewModeOption get viewMode => _viewMode;
  bool get isCardView => _viewMode == ViewModeOption.card;

  ThemeProvider() {
    _loadTheme();
    _loadViewMode();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeKey);
    if (savedMode != null) {
      _themeMode = ThemeModeOption.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => ThemeModeOption.system,
      );
      notifyListeners();
    }
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_viewModeKey);
    if (savedMode != null) {
      _viewMode = ViewModeOption.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => ViewModeOption.card,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> setViewMode(ViewModeOption mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode.name);
    notifyListeners();
  }

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }

  bool get isDarkMode {
    if (_themeMode == ThemeModeOption.dark) return true;
    if (_themeMode == ThemeModeOption.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// 与 [AppThemeColors] 同源，保留 `ThemeProvider.xxx` 供全工程引用。
  static const Color primaryColor = AppThemeColors.primaryColor;
  static const Color primaryColorDark = AppThemeColors.primaryColorDark;
  static const Color secondaryColor = AppThemeColors.secondaryColor;
  static const Color accentColor = AppThemeColors.accentColor;
  static const Color lightBackgroundColor = AppThemeColors.lightBackgroundColor;
  static const Color darkBackgroundColor = AppThemeColors.darkBackgroundColor;
  static const Color lightCardColor = AppThemeColors.lightCardColor;
  static const Color darkCardColor = AppThemeColors.darkCardColor;
  static const Color lightTextColor = AppThemeColors.lightTextColor;
  static const Color darkTextColor = AppThemeColors.darkTextColor;
  static const Color lightSecondaryTextColor =
      AppThemeColors.lightSecondaryTextColor;
  static const Color darkSecondaryTextColor =
      AppThemeColors.darkSecondaryTextColor;
  static const Color lightBorderColor = AppThemeColors.lightBorderColor;
  static const Color darkBorderColor = AppThemeColors.darkBorderColor;
  static const Color categoryTagLightBg = AppThemeColors.categoryTagLightBg;
  static const Color categoryTagDarkBg = AppThemeColors.categoryTagDarkBg;

  ThemeData get theme {
    return isDarkMode ? darkTheme : lightTheme;
  }

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      background: lightBackgroundColor,
      surface: lightCardColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: lightTextColor,
      onSurface: lightTextColor,
    ),
    scaffoldBackgroundColor: lightBackgroundColor,
    cardColor: lightCardColor,
    fontFamily: 'PingFang SC',
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightTextColor),
      displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightTextColor),
      displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: lightTextColor),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: lightTextColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: lightTextColor),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: lightSecondaryTextColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    iconTheme: IconThemeData(
      color: lightTextColor,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppGlassNavBarTheme.light,
    ],
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      background: darkBackgroundColor,
      surface: darkCardColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: darkTextColor,
      onSurface: darkTextColor,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    fontFamily: 'PingFang SC',
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkTextColor),
      displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextColor),
      displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextColor),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: darkTextColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: darkTextColor),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: darkSecondaryTextColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    iconTheme: IconThemeData(
      color: darkTextColor,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppGlassNavBarTheme.dark,
    ],
  );
}
