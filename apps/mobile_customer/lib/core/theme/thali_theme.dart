import 'package:flutter/material.dart';

class ThaliTheme {
  static const Color cream = Color(0xFFFBF6EE);
  static const Color navy = Color(0xFF182435);
  static const Color orange = Color(0xFFFF6B1A);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE9E0D5);
  static const Color muted = Color(0xFF687382);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: orange,
        onPrimary: Colors.white,
        secondary: navy,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: navy,
        error: const Color(0xFFB42318),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: cream,
      // Typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Montserrat', color: navy),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Montserrat', color: navy),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', color: navy),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', color: navy),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Montserrat', color: navy),
        bodyLarge: TextStyle(fontSize: 15, fontFamily: 'OpenSans', color: navy),
        bodyMedium: TextStyle(fontSize: 13.5, fontFamily: 'OpenSans', color: navy),
        bodySmall: TextStyle(fontSize: 12, fontFamily: 'OpenSans', color: muted),
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: navy, size: 24),
        titleTextStyle: TextStyle(fontSize: 20, color: navy, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44), // Ensure ≥44x44 tap area
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Montserrat'),
        ),
      ),
      // Cards
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: orange, width: 1.5)),
      ),
      // Icons
      iconTheme: const IconThemeData(size: 24, color: navy),
    );
  }
}
