import 'package:flutter/material.dart';

class MessColors {
  // Brand
  static const cream = Color(0xFFFBF6EE); // --mess-bg
  static const bg = Color(0xFFFBF6EE);
  static const creamDeep = Color(0xFFF2E9DA);
  static const white = Color(0xFFFFFFFF); // --mess-surface
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF182435); // --mess-ink
  static const navy = Color(0xFF182435);
  static const navySoft = Color(0xFF263746);
  static const muted = Color(0xFF687382); // --mess-muted

  // Accent
  static const orange = Color(0xFFFF6B1A); // --mess-orange
  static const orangeDark = Color(0xFFE94E12); // --mess-orange-pressed
  static const orangePressed = Color(0xFFE94E12);
  static const orangeSoft = Color(0xFFFFF0E5); // --mess-orange-soft

  // Status
  static const green = Color(0xFF1F9D63); // --mess-success
  static const success = Color(0xFF1F9D63);
  static const greenSoft = Color(0xFFE7F7EE); // --mess-success-soft
  static const successSoft = Color(0xFFE7F7EE);
  static const red = Color(0xFFB42318); // --mess-error
  static const error = Color(0xFFB42318);
  static const disabled = Color(0xFF9AA3AC); // --mess-disabled

  // Borders & Elevation
  static const border = Color(0xFFE9E0D5); // --mess-border
  static const shadow = BoxShadow(
    color: Color(0x122A1F14), // rgba(42, 31, 20, 0.07)
    blurRadius: 18,
    offset: Offset(0, 4),
  );

  // Shape Radii
  static const double radiusControl = 14.0;
  static const double radiusCard = 16.0;
  static const double radiusFeature = 20.0;
  static const double radiusPill = 999.0;
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
        fontFamily: 'Montserrat',
      ).copyWith(
        headlineLarge: const TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w800, color: MessColors.navy, letterSpacing: -0.5),
        headlineMedium: const TextStyle(fontSize: 22, height: 1.18, fontWeight: FontWeight.w800, color: MessColors.navy, letterSpacing: -0.3),
        titleLarge: const TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w800, color: MessColors.navy),
        titleMedium: const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w700, color: MessColors.navy),
        bodyLarge: const TextStyle(fontSize: 15, height: 1.45, color: MessColors.ink),
        bodyMedium: const TextStyle(fontSize: 13.5, height: 1.4, color: MessColors.ink),
        bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: MessColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MessColors.cream,
        foregroundColor: MessColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MessColors.navy, fontFamily: 'Montserrat'),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MessColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: MessColors.muted, fontSize: 14),
        prefixIconColor: MessColors.muted,
        suffixIconColor: MessColors.muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl), borderSide: const BorderSide(color: MessColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl), borderSide: const BorderSide(color: MessColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl), borderSide: const BorderSide(color: MessColors.orange, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl), borderSide: const BorderSide(color: MessColors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl), borderSide: const BorderSide(color: MessColors.red, width: 1.5)),
      ),
      cardTheme: CardThemeData(
        color: MessColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MessColors.radiusCard),
          side: const BorderSide(color: MessColors.border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerColor: MessColors.border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MessColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MessColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MessColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MessColors.radiusFeature)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: MessColors.white,
        selectedColor: MessColors.orangeSoft,
        side: const BorderSide(color: MessColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MessColors.radiusControl)),
        labelStyle: const TextStyle(fontSize: 12, color: MessColors.ink, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MessColors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MessColors.radiusControl),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
