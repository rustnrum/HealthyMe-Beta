import 'package:flutter/material.dart';

class AppTheme {
  static const Color cyan = Color(0xFF17C8F4);
  static const Color mint = Color(0xFF35E39A);
  static const Color purple = Color(0xFF9B65F7);
  static const Color amber = Color(0xFFFFB84D);
  static const Color rose = Color(0xFFFF5C74);

  static ThemeData get dark {
    const background = Color(0xFF03131D);
    const surface = Color(0xFF082331);
    const surface2 = Color(0xFF0B2C3B);

    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: cyan,
      secondary: mint,
      tertiary: purple,
      surface: surface,
      surfaceContainer: surface,
      surfaceContainerHighest: surface2,
      outlineVariant: const Color(0xFF1D4657),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: const Color(0xFF061A24),
        indicatorColor: cyan.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
