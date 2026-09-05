import 'package:flutter/material.dart';

class PraharTheme {
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color darkBg = Color(0xFF0F1714);
  static const Color cardBg = Color(0xFF16231E);
  static const Color borderGreen = Color(0xFF233830);
  static const Color alertAmber = Color(0xFFF59E0B);
  static const Color alertRose = Color(0xFFF43F5E);
  static const Color alertSky = Color(0xFF0EA5E9);

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
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGreen, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
