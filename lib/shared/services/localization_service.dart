import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app language preference with persistence.
///
/// Usage:
///   MaterialApp(locale: LocalizationService.instance.locale, ...)
///   LocalizationService.instance.setLocale(const Locale('hi'));
class LocalizationService extends ChangeNotifier {
  LocalizationService._();

  static final LocalizationService instance = LocalizationService._();

  static const String _localeKey = 'app_locale';
  static const String _defaultLanguage = 'en';

  Locale _locale = const Locale(_defaultLanguage);

  /// Current locale.
  Locale get locale => _locale;

  /// Whether the current language is Hindi.
  bool get isHindi => _locale.languageCode == 'hi';

  /// Human-readable name of current language.
  String get currentLanguageName => isHindi ? 'हिन्दी' : 'English';

  /// Initializes the service by loading the persisted language preference.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey) ?? _defaultLanguage;
      _locale = Locale(code);
    } catch (_) {
      _locale = const Locale(_defaultLanguage);
    }
  }

  /// Sets the app locale and persists it.
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (_) {}
  }

  /// Switches to Hindi.
  Future<void> setHindi() => setLocale(const Locale('hi'));

  /// Switches to English.
  Future<void> setEnglish() => setLocale(const Locale('en'));
}
