import 'package:flutter/material.dart';

class ThaliTheme {
  static const Color cream = Color(0xFFFCF6E8);
  static const Color navy = Color(0xFF0B2545);
  static const Color orange = Color(0xFFFF6F21);
  static const Color white = Colors.white;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: navy,
        onPrimary: Colors.white,
        secondary: orange,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: navy,
        error: Colors.red.shade700,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: cream,
      // Typography
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
        bodyLarge: TextStyle(fontSize: 16, fontFamily: 'OpenSans'),
        bodySmall: TextStyle(fontSize: 12, fontFamily: 'OpenSans'),
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        elevation: 0,
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
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontSize: 16, fontFamily: 'OpenSans'),
        ),
      ),
      // Cards
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      // Icons
      iconTheme: const IconThemeData(size: 24, color: navy),
    );
  }
}
