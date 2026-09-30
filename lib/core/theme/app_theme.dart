import 'package:flutter/material.dart';

class AppTheme {
  // Palette sampled from the approved Healthy Me command-center mockup.
  static const Color background = Color(0xFF041A26);
  static const Color backgroundDeep = Color(0xFF03131D);
  static const Color surface = Color(0xFF092535);
  static const Color surfaceHigh = Color(0xFF0D3143);
  static const Color surfaceMuted = Color(0xFF102B39);
  static const Color border = Color(0xFF203D4B);

  static const Color cyan = Color(0xFF1B97EB);
  static const Color mint = Color(0xFF23D0B1);
  static const Color teal = Color(0xFF177382);
  static const Color purple = Color(0xFF835BFF);
  static const Color amber = Color(0xFFF3A62E);
  static const Color rose = Color(0xFFF85986);
  static const Color blue = Color(0xFF2F75F2);

  static const Color textPrimary = Color(0xFFE0E5EA);
  static const Color textSecondary = Color(0xFFA3B0BD);
  static const Color textMuted = Color(0xFF6E8290);

  static ThemeData get dark {
    final scheme = const ColorScheme.dark().copyWith(
      primary: cyan,
      secondary: mint,
      tertiary: purple,
      surface: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: border,
      outlineVariant: border,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundDeep,
      fontFamily: null,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          height: 1.35,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDeep,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cyan, width: 1.3),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 0.8,
        space: 18,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cyan),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: cyan.withValues(alpha: 0.18),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
