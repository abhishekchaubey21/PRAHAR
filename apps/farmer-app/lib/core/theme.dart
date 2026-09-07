import 'package:flutter/material.dart';

class PraharTheme {
  static const Color primaryGreen = Color(0xFF22C55E);
  static const Color darkBg = Color(0xFF0A150F);
  static const Color cardBg = Color(0xFF13241C);
  static const Color borderGreen = Color(0xFF1F382B);
  static const Color alertAmber = Color(0xFFF59E0B);
  static const Color alertRose = Color(0xFFF43F5E);
  static const Color alertSky = Color(0xFF38BDF8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: alertAmber,
        surface: cardBg,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderGreen, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
