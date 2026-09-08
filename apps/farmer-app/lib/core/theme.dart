import 'package:flutter/material.dart';

class PraharTheme {
  // ── Light Farmer-First Color Tokens ─────────────────────────────────────
  // Primary greens (healthy, positive, confirmed)
  static const Color primaryGreen = Color(0xFF16A34A);      // Forest green
  static const Color primaryGreenLight = Color(0xFFDCFCE7); // Mint wash
  static const Color darkGreen = Color(0xFF14532D);         // Dark heading text
  static const Color mediumGreen = Color(0xFF15803D);       // Action buttons

  // Orange / amber (attention, warning, recommended action)
  static const Color alertAmber = Color(0xFFD97706);
  static const Color alertAmberLight = Color(0xFFFFF7ED);

  // Red (critical safety, prohibited)
  static const Color alertRose = Color(0xFFDC2626);
  static const Color alertRoseLight = Color(0xFFFFF1F2);

  // Sky (informational accents, judge mode)
  static const Color alertSky = Color(0xFF0284C7);
  static const Color alertSkyLight = Color(0xFFE0F2FE);

  // Background & card
  static const Color lightBg = Color(0xFFF8FAF9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgGreen = Color(0xFFF0FDF4); // Subtle green wash on cards
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderGreen = Color(0xFFBBF7D0);

  // Text
  static const Color textHeading = Color(0xFF14532D);  // Dark forest green
  static const Color textBody = Color(0xFF1E293B);     // Slate
  static const Color textMuted = Color(0xFF64748B);    // Slate muted
  static const Color textWhite = Color(0xFFFFFFFF);

  // Legacy dark-theme tokens kept for backward compatibility in any
  // remaining dark-only widgets (voice dialogs etc.)
  static const Color darkBg = Color(0xFF0A150F);
  static const Color darkCardBg = Color(0xFF13241C);
  static const Color borderDark = Color(0xFF1F382B);

  // ── Light (Farmer-First) Theme ───────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: alertAmber,
        surface: cardBg,
        onPrimary: Colors.white,
        onSurface: textBody,
        error: alertRose,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textHeading,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textHeading),
        actionsIconTheme: IconThemeData(color: textHeading),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryGreenLight,
        labelStyle: const TextStyle(color: darkGreen, fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: borderGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight),
        ),
      ),
    );
  }

  // Legacy dark theme retained (used by test environments or older widgets)
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: alertAmber,
        surface: darkCardBg,
      ),
      cardTheme: CardThemeData(
        color: darkCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderDark, width: 1),
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
