import 'package:flutter/material.dart';

class AppTheme {
  // Brand palette inspired by the MediTwin mark: clinical blue, medical teal,
  // calm mint surfaces, and a restrained navy text system.
  static const Color primaryNavy = Color(0xFF102A43);
  static const Color primaryBlue = Color(0xFF1769AA);
  static const Color primaryTeal = Color(0xFF00A79D);
  static const Color accentCyan = Color(0xFF2EC4E6);
  static const Color accentMint = Color(0xFFE6FAF7);
  static const Color accentGold = Color(0xFFF4C95D);

  static const Color scaffold = Color(0xFFF5F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF0F7FA);
  static const Color surfaceTint = Color(0xFFEAF7F5);
  static const Color border = Color(0xFFDDE8EF);

  static const Color textPrimary = Color(0xFF14213D);
  static const Color textSecondary = Color(0xFF4F6475);
  static const Color textMuted = Color(0xFF7B8D9B);
  static const Color onBrand = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF2EAD7A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE25454);
  static const Color info = Color(0xFF2F80ED);

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryNavy, primaryBlue, primaryTeal],
  );

  static const LinearGradient softBrandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAF7FF), Color(0xFFE7FBF6), Color(0xFFFFFFFF)],
  );

  static List<BoxShadow> softShadow({double opacity = 0.08}) {
    return [
      BoxShadow(
        color: primaryNavy.withValues(alpha: opacity),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryTeal,
      brightness: Brightness.light,
      primary: primaryBlue,
      secondary: primaryTeal,
      tertiary: accentCyan,
      error: danger,
      surface: surface,
    ).copyWith(
      onPrimary: onBrand,
      onSecondary: onBrand,
      onSurface: textPrimary,
      outline: border,
      surfaceContainerHighest: surfaceSoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: textPrimary,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: textPrimary,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: textPrimary,
          height: 1.45,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
          height: 1.45,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: textMuted,
          height: 1.35,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shadowColor: primaryNavy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.9),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(color: primaryTeal, fontWeight: FontWeight.w700),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryTeal, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: onBrand,
          disabledBackgroundColor: border,
          disabledForegroundColor: textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: onBrand,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceSoft,
        selectedColor: accentMint,
        checkmarkColor: primaryTeal,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.96),
        indicatorColor: accentMint,
        surfaceTintColor: Colors.transparent,
        shadowColor: primaryNavy.withValues(alpha: 0.08),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primaryBlue : textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryBlue : textMuted,
            size: selected ? 25 : 23,
          );
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: textMuted,
        indicatorColor: primaryTeal,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryNavy,
        contentTextStyle: const TextStyle(color: onBrand, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryTeal,
        linearTrackColor: surfaceSoft,
        circularTrackColor: surfaceSoft,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      listTileTheme: const ListTileThemeData(
        iconColor: primaryBlue,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primaryTeal : textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? primaryTeal.withValues(alpha: 0.24)
              : border.withValues(alpha: 0.7);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primaryTeal : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(onBrand),
        side: const BorderSide(color: border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primaryTeal : textMuted;
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
    );
  }
}
