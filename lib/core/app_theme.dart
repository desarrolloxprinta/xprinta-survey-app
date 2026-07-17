import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (from tokens.ts)
  static const Color primary = Color(0xFFFA8029); // Orange Xprinta
  static const Color primaryHover = Color(0xFFE87424);
  
  // Light Mode Colors
  static const Color backgroundLight = Color(0xFFF5F5F5); // backgroundSecondary
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF5F6062);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFDCDCDC);
  
  // Dark Mode Colors (Slate)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFCBD5E1); // Slate 300
  static const Color borderDark = Color(0x1AFFFFFF); // 10% white

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryHover,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSurface: textPrimaryLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimaryLight),
        titleTextStyle: GoogleFonts.questrial(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.manrope(color: textPrimaryLight),
        bodyMedium: GoogleFonts.manrope(color: textSecondaryLight),
        titleLarge: GoogleFonts.questrial(color: textPrimaryLight, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.questrial(color: textPrimaryLight, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryHover,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSurface: textPrimaryDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.questrial(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.manrope(color: textPrimaryDark),
        bodyMedium: GoogleFonts.manrope(color: textSecondaryDark),
        titleLarge: GoogleFonts.questrial(color: textPrimaryDark, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.questrial(color: textPrimaryDark, fontWeight: FontWeight.bold),
      ),
    );
  }
}
