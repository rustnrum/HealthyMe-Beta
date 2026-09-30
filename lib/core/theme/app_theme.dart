import 'package:flutter/material.dart';

class AppTheme {
  // Tuned to the approved five-screen Healthy Me command-center design.
  static const Color background = Color(0xFF031A27);
  static const Color backgroundDeep = Color(0xFF02131E);
  static const Color surface = Color(0xFF082A3C);
  static const Color surfaceHigh = Color(0xFF0B3449);
  static const Color surfaceMuted = Color(0xFF0C2F41);
  static const Color border = Color(0xFF1C4960);

  static const Color cyan = Color(0xFF1AA7F5);
  static const Color mint = Color(0xFF28DDB8);
  static const Color teal = Color(0xFF16889B);
  static const Color purple = Color(0xFF8B6CFF);
  static const Color amber = Color(0xFFFFB23D);
  static const Color rose = Color(0xFFFF5F8F);
  static const Color blue = Color(0xFF397CFF);

  static const Color textPrimary = Color(0xFFF2F5F8);
  static const Color textSecondary = Color(0xFFC0CAD3);
  static const Color textMuted = Color(0xFF8799A7);

  // Readability floor for the app. Avoid tiny 8–11px text.
  static const double body = 15;
  static const double detail = 13;
  static const double label = 13;
  static const double section = 21;

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
      splashColor: cyan.withValues(alpha: 0.08),
      highlightColor: cyan.withValues(alpha: 0.04),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.9,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 27,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.45,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: body,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: detail,
          height: 1.38,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontSize: label,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDeep,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cyan, width: 1.4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 0.8,
        space: 20,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: cyan.withValues(alpha: 0.18),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
