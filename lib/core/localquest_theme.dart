import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class LqColors {
  static const background = Color(0xFFF6F6F2);
  static const surface = Colors.white;
  static const ink = Color(0xFF17233F);
  static const muted = Color(0xFF78849A);
  static const primary = Color(0xFF3267D4);
  static const primaryDark = Color(0xFF1B34AE);
  static const primarySoft = Color(0xFFDCE8FF);
  static const greenSoft = Color(0xFFD5E4C1);
  static const peachSoft = Color(0xFFF8DED1);
  static const field = Color(0xFFF7F8FB);
  static const line = Color(0xFFDFE4ED);
  static const danger = Color(0xFFA6051A);
  static const success = Color(0xFF4DAA70);
}

ThemeData localQuestTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LqColors.primary,
      primary: LqColors.primary,
      surface: LqColors.surface,
      error: LqColors.danger,
    ),
    scaffoldBackgroundColor: LqColors.background,
  );
  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(
      base.textTheme,
    ).apply(bodyColor: LqColors.ink, displayColor: LqColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LqColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: LqColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: LqColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: LqColors.primary, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LqColors.ink,
    ),
  );
}

TextStyle get monoLabel => GoogleFonts.dmMono(
  color: LqColors.muted,
  fontSize: 10,
  letterSpacing: 1.6,
  fontWeight: FontWeight.w500,
);
