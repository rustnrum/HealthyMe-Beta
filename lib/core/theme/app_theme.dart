import 'package:flutter/material.dart';

class AppTheme {
  // Salus visual system v25 — deep midnight glass with electric cyan/mint light.
  static const Color background = Color(0xFF05090D);
  static const Color backgroundDeep = Color(0xFF03070A);
  static const Color surface = Color(0xFF0A1218);
  static const Color surfaceHigh = Color(0xFF101B23);
  static const Color surfaceMuted = Color(0xFF15232D);
  static const Color border = Color(0xFF24404F);

  static const Color cyan = Color(0xFF62E8F2);
  static const Color mint = Color(0xFF55E6C1);
  static const Color teal = Color(0xFF36C7C9);
  static const Color purple = Color(0xFF9D7BFF);
  static const Color amber = Color(0xFFFFC566);
  static const Color rose = Color(0xFFFF7E92);
  static const Color blue = Color(0xFF5CB9FF);

  static const Color textPrimary = Color(0xFFF3F7FA);
  static const Color textSecondary = Color(0xFFAEBBC5);
  static const Color textMuted = Color(0xFF70818D);
  static const Color creamText = Color(0xFFF7FAFC);

  static const double body = 15;
  static const double detail = 13;
  static const double label = 13;
  static const double section = 21;

  static LinearGradient get pageGlow => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF07131C),
          Color(0xFF05090D),
          Color(0xFF020507),
        ],
      );

  static LinearGradient get glassGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xE612202A), Color(0xD90A1218)],
      );

  static ThemeData get dark {
    final scheme = const ColorScheme.dark().copyWith(
      primary: cyan,
      secondary: mint,
      tertiary: blue,
      surface: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceMuted,
      outline: border,
      outlineVariant: border,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashColor: cyan.withValues(alpha: 0.08),
      highlightColor: cyan.withValues(alpha: 0.04),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 38, fontWeight: FontWeight.w500, letterSpacing: -1.2),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.8),
        headlineSmall: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4),
        titleLarge: TextStyle(color: textPrimary, fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.42),
        bodyMedium: TextStyle(color: textPrimary, fontSize: body, height: 1.4),
        bodySmall: TextStyle(color: textSecondary, fontSize: detail, height: 1.38),
        labelLarge: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: textSecondary, fontSize: label, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: border, width: 0.9),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.7),
        thickness: 0.7,
        space: 18,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh.withValues(alpha: 0.82),
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: cyan, width: 1.35)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF3F7FA),
          foregroundColor: const Color(0xFF081017),
          minimumSize: const Size(0, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cyan),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: border)),
        textStyle: const TextStyle(color: textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: border)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cyan,
        inactiveTrackColor: border,
        thumbColor: const Color(0xFFF3F7FA),
        overlayColor: cyan.withValues(alpha: 0.12),
        valueIndicatorColor: surfaceHigh,
        valueIndicatorTextStyle: const TextStyle(color: textPrimary),
      ),
    );
  }
}
