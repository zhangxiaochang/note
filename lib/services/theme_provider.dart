import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeOption { light, dark, system }
enum ViewModeOption { card, list }

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
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  // 主色 - Apple Notes 黄色风格
  static const Color primaryColor = Color(0xFFFFB800);  // 金色/黄色
  static const Color primaryColorDark = Color(0xFFD4A017);  // 深金色
  // 辅助色
  static const Color secondaryColor = Color(0xFF10B981);
  // 强调色 - Apple Notes 黄色
  static const Color accentColor = Color(0xFFFFB800);
  // 背景色 - Apple Notes 风格
  static const Color lightBackgroundColor = Color(0xFFFFFFFF);  // 纯白
  static const Color darkBackgroundColor = Color(0xFF1C1C1E);  // Apple深色背景
  // 卡片色
  static const Color lightCardColor = Color(0xFFFFFFFF);  // 纯白卡片
  static const Color darkCardColor = Color(0xFF2C2C2E);   // Apple深色卡片
  // 文本色 - Apple Notes 风格
  static const Color lightTextColor = Color(0xFF000000);      // 黑色
  static const Color darkTextColor = Color(0xFFFFFFFF);       // 白色
  static const Color lightSecondaryTextColor = Color(0xFF8E8E93);  // Apple灰色
  static const Color darkSecondaryTextColor = Color(0xFF8E8E93);   // Apple灰色
  // 边框色
  static const Color lightBorderColor = Color(0xFFE5E5EA);
  static const Color darkBorderColor = Color(0xFF38383A);
  // 分类标签背景色
  static const Color categoryTagLightBg = Color(0xFFF2F2F7);
  static const Color categoryTagDarkBg = Color(0xFF3A3A3C);

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
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    ),
    iconTheme: IconThemeData(
      color: lightTextColor,
    ),
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
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    ),
    iconTheme: IconThemeData(
      color: darkTextColor,
    ),
  );
}
