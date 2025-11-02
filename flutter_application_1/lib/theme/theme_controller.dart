import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  static const _prefsKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.light);
  ValueListenable<ThemeMode> get listenable => _themeMode;
  ThemeMode get themeMode => _themeMode.value;
  bool get isDark => _themeMode.value == ThemeMode.dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    switch (saved) {
      case 'light':
        _themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        _themeMode.value = ThemeMode.dark;
        break;
      case 'system':
        _themeMode.value = ThemeMode.system;
        break;
      default:
        // Default to light mode for new installations
        _themeMode.value = ThemeMode.light;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
          ? 'dark'
          : 'system',
    );
  }

  Future<void> toggle() async {
    await setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
