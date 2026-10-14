import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF05080D);
  static const card = Color(0xFF0E141C);
  static const cardTop = Color(0xFF121A25);
  static const border = Color(0xFF1C2632);
  static const sub = Color(0xFF8D98A6);
  static const green = Color(0xFF34D399);
  static const teal = Color(0xFF2DD4BF);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF3B82F6);
  static const indigo = Color(0xFF5B5BE0);
  static const purple = Color(0xFF8B7CF6);
  static const orange = Color(0xFFF59E0B);
  static const pink = Color(0xFFEC6AA8);
  static const red = Color(0xFFEF4444);
}

/// Text style helper. The device's installed font is used.
TextStyle ts(double size,
    {int w = 400, Color color = Colors.white, double? ls, double? h}) {
  return TextStyle(
    fontSize: size,
    color: color,
    letterSpacing: ls,
    height: h,
    fontWeight: FontWeight.values[(w ~/ 100) - 1],
  );
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(primary: C.cyan, surface: C.card),
  );
}
