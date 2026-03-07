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
}
