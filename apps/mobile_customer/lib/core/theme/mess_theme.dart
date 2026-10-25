import 'package:flutter/material.dart';

class MessColors {
  static const cream = Color(0xFFFAF6EE);
  static const creamDeep = Color(0xFFF2E9DA);
  static const white = Color(0xFFFFFEFC);
  static const navy = Color(0xFF111F2C);
  static const navySoft = Color(0xFF263746);
  static const orange = Color(0xFFF29A16);
  static const orangeDark = Color(0xFFD97908);
  static const green = Color(0xFF16834A);
  static const greenSoft = Color(0xFFE7F5E9);
  static const ink = Color(0xFF172635);
  static const muted = Color(0xFF6C7883);
  static const border = Color(0xFFE9E2D7);
  static const red = Color(0xFFB93832);
}

class MessTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: MessColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MessColors.orange,
        primary: MessColors.orange,
        secondary: MessColors.navy,
        surface: MessColors.white,
        error: MessColors.red,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: MessColors.ink,
        displayColor: MessColors.ink,
        fontFamily: 'Arial',
      ).copyWith(
        headlineLarge: const TextStyle(fontSize: 28, height: 1.12, fontWeight: FontWeight.w800, color: MessColors.navy, letterSpacing: -0.6),
        headlineMedium: const TextStyle(fontSize: 23, height: 1.15, fontWeight: FontWeight.w800, color: MessColors.navy, letterSpacing: -0.4),
        titleLarge: const TextStyle(fontSize: 19, height: 1.2, fontWeight: FontWeight.w700, color: MessColors.navy),
        titleMedium: const TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, color: MessColors.navy),
        bodyLarge: const TextStyle(fontSize: 15, height: 1.45, color: MessColors.ink),
        bodyMedium: const TextStyle(fontSize: 13.5, height: 1.4, color: MessColors.ink),
        bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: MessColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MessColors.cream,
        foregroundColor: MessColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: MessColors.navy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MessColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        hintStyle: const TextStyle(color: MessColors.muted, fontSize: 14),
        prefixIconColor: MessColors.muted,
        suffixIconColor: MessColors.muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MessColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MessColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MessColors.orange, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MessColors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MessColors.red, width: 1.5)),
      ),
      dividerColor: MessColors.border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MessColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MessColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MessColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: MessColors.white,
        selectedColor: const Color(0xFFFFE8BF),
        side: const BorderSide(color: MessColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(fontSize: 12, color: MessColors.ink, fontWeight: FontWeight.w600),
      ),
    );
  }
}
