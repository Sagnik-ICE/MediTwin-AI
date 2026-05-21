import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryDeepBlue = Color(0xFF0D1B2A);
  static const Color primaryTeal = Color(0xFF1B998B);
  static const Color primaryCyan = Color(0xFF3E92CC);
  static const Color primaryGold = Color(0xFFF2C14E);
  static const Color surfaceInk = Color(0xFF10263D);
  static const Color textMuted = Color(0xFF6B7C93);
  static const Color success = Color(0xFF3CB371);
  static const Color warning = Color(0xFFF4A261);
  static const Color danger = Color(0xFFE76F51);

  static ThemeData lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        primary: primaryDeepBlue,
        secondary: primaryTeal,
        tertiary: primaryCyan,
        surface: const Color(0xFFF6F9FC),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F8FB),
    );

    return base.copyWith(
      splashColor: primaryTeal.withValues(alpha: 0.12),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryDeepBlue.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryTeal, width: 1.8),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        margin: const EdgeInsets.all(0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        indicatorColor: primaryTeal.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDeepBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDeepBlue,
          side: BorderSide(color: primaryDeepBlue.withValues(alpha: 0.20)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryCyan,
        brightness: Brightness.dark,
        primary: const Color(0xFFEAF2FF),
        secondary: primaryCyan,
        tertiary: primaryGold,
        surface: const Color(0xFF0E1A27),
      ),
      scaffoldBackgroundColor: const Color(0xFF08131D),
    );

    return base.copyWith(
      splashColor: primaryCyan.withValues(alpha: 0.16),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF122235),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryCyan, width: 1.8),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF122235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        margin: const EdgeInsets.all(0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF102132).withValues(alpha: 0.92),
        indicatorColor: primaryCyan.withValues(alpha: 0.18),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
