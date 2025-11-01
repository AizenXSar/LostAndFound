import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const Color primary = Colors.black;
    const Color onPrimary = Colors.white;
    const Color surface = Colors.white;
    const Color onSurface = Colors.black;
    const Color surfaceVariant = Color(0xFFEEEEEE);

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        secondary: primary,
        onSecondary: onPrimary,
        error: Colors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const Color primary = Colors.white;
    const Color onPrimary = Colors.black;
    const Color surface = Colors.black;
    const Color onSurface = Colors.white;
    const Color surfaceVariant = Color(0xFF1E1E1E);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        secondary: primary,
        onSecondary: onPrimary,
        error: Colors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
