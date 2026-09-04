import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and manages the app's theme mode (light, dark, system).
///
/// Extends [ChangeNotifier] so [AnimatedBuilder] in app.dart rebuilds
/// the MaterialApp when the theme changes.
///
/// Usage:
///   final themeService = ThemeService.instance;
///   await themeService.init(); // Call once at app start
///   MaterialApp(themeMode: themeService.themeMode, ...)
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _themeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  /// Current theme mode (system, light, or dark).
  ThemeMode get themeMode => _themeMode;

  /// Whether the current effective theme is dark.
  bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Initializes the theme service by loading the persisted preference.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeKey);
      if (saved != null) {
        _themeMode = _parseThemeMode(saved);
      }
    } catch (_) {
      // Default to system theme on error.
      _themeMode = ThemeMode.system;
    }
  }

  /// Sets the theme mode and persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
    } catch (_) {}
  }

  /// Switches to light theme.
  Future<void> setLight() => setThemeMode(ThemeMode.light);

  /// Switches to dark theme.
  Future<void> setDark() => setThemeMode(ThemeMode.dark);

  /// Switches to system default.
  Future<void> setSystem() => setThemeMode(ThemeMode.system);

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
