import 'package:flutter/material.dart';

class AppTheme {
  // Salus by Rust N Rum — warm parchment, aged bronze and olive.
  static const Color background = Color(0xFFF1E4C9);
  static const Color backgroundDeep = Color(0xFF1C1109);
  static const Color surface = Color(0xFFF7EEDC);
  static const Color surfaceHigh = Color(0xFFEEDDBD);
  static const Color surfaceMuted = Color(0xFFE3CFA9);
  static const Color border = Color(0xFFA8844E);

  static const Color cyan = Color(0xFFC89A4B);
  static const Color mint = Color(0xFF6C7849);
  static const Color teal = Color(0xFF5D746A);
  static const Color purple = Color(0xFF786657);
  static const Color amber = Color(0xFFC38738);
  static const Color rose = Color(0xFFA45A49);
  static const Color blue = Color(0xFF557789);

  static const Color textPrimary = Color(0xFF2A1A10);
  static const Color textSecondary = Color(0xFF6A5540);
  static const Color textMuted = Color(0xFF927B61);
  static const Color creamText = Color(0xFFF4E6C9);

  static const double body = 15;
  static const double detail = 13;
  static const double label = 13;
  static const double section = 21;

  static ThemeData get dark {
    final scheme = const ColorScheme.light().copyWith(
      primary: mint,
      secondary: amber,
      tertiary: blue,
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
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'serif',
      splashColor: amber.withValues(alpha: 0.09),
      highlightColor: amber.withValues(alpha: 0.05),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        headlineSmall: TextStyle(color: textPrimary, fontSize: 23, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: textPrimary, fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(color: textPrimary, fontSize: body, height: 1.4),
        bodySmall: TextStyle(color: textSecondary, fontSize: detail, height: 1.38),
        labelLarge: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: textSecondary, fontSize: label, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDeep,
        foregroundColor: creamText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        titleTextStyle: TextStyle(color: creamText, fontFamily: 'serif', fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: border, width: 0.9)),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 0.7, space: 18),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: mint, width: 1.4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: mint, foregroundColor: creamText, minimumSize: const Size(0, 50), textStyle: const TextStyle(fontFamily: 'serif', fontSize: 15, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: textPrimary, minimumSize: const Size(0, 50), side: const BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: border)),
        textStyle: const TextStyle(color: textPrimary, fontFamily: 'serif'),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: border))),
      snackBarTheme: SnackBarThemeData(backgroundColor: backgroundDeep, contentTextStyle: const TextStyle(color: creamText, fontSize: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating),
    );
  }
}
