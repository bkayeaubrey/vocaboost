import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Main color: Deep Purple 
/// Accent:      Amber     
/// Supporting:  Soft Lavender & Midnight Gray for balance
class VocaBoostTheme {
  static const Color primary = Color(0xFF673AB7); // Deep purple
  static const Color secondary = Color(0xFFFFC107); // Amber accent
  static const Color lightBackground = Color(0xFFF4EEFF); // Soft lavender
  static const Color darkBackground = Color(0xFF121212);
  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF1E1E1E);

  /// Blue Hour Color Palette (used in most screens)
  static const Color kPrimary = Color(0xFF3B5FAE);
  static const Color kAccent = Color(0xFF2666B4);

  /// Get Poppins text theme
  static TextTheme _getTextTheme(Brightness brightness) {
    final baseColor = brightness == Brightness.light ? Colors.black87 : Colors.white70;
    return GoogleFonts.poppinsTextTheme(
      TextTheme(
        displayLarge: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: baseColor),
        bodyMedium: TextStyle(color: baseColor),
        bodySmall: TextStyle(color: baseColor),
        labelLarge: TextStyle(color: baseColor, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: baseColor),
        labelSmall: TextStyle(color: baseColor),
      ),
    );
  }

  /// Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: lightCard,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.black87,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 2,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    cardColor: lightCard,
    textTheme: _getTextTheme(Brightness.light),
  );

  /// Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: darkCard,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.white70,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 1,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    cardColor: darkCard,
    textTheme: _getTextTheme(Brightness.dark),
  );
}
