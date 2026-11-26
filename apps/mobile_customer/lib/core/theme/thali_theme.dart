import 'package:flutter/material.dart';

class ThaliColors {
  ThaliColors._();

  // Primary Brand Orange Scale (Behance Spec)
  static const Color primary = Color(0xFFE95F35);
  static const Color primaryShade1 = Color(0xFFBB4D00);
  static const Color primaryDark = Color(0xFFCC4A22);
  static const Color primaryPressed = Color(0xFFA83B1C);
  static const Color primaryDeep = Color(0xFF8A321A);
  static const Color primarySoft = Color(0xFFFFF3EE);
  static const Color heroSubtle = Color(0xFFFDF1ED);

  // Neutral Grey & Surfaces
  static const Color card = Color(0xFFFFFFFF);
  static const Color scaffold = Color(0xFFFAFAFA);
  static const Color subtle = Color(0xFFF4F4F5);
  static const Color stroke = Color(0xFFE4E4E7);
  static const Color border = Color(0xFFD4D4D8);

  // Ink Scale
  static const Color ink = Color(0xFF18181B);
  static const Color body = Color(0xFF52525C);
  static const Color muted = Color(0xFF71717B);
  static const Color hint = Color(0xFF9F9FA9);

  // Semantics & 6 Meal Status Tokens
  static const Color green = Color(0xFF16A34A);
  static const Color greenDark = Color(0xFF15803D);
  static const Color greenSoft = Color(0xFFF0FDF4);
  static const Color greenBorder = Color(0xFF86EFAC);

  static const Color blue = Color(0xFF0284C7);
  static const Color blueSoft = Color(0xFFF0F9FF);
  static const Color blueBorder = Color(0xFF7DD3FC);

  static const Color amber = Color(0xFFD97706);
  static const Color amberDark = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFCD34D);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color redBorder = Color(0xFFFCA5A5);

  // Explore Quick Slot Tiles
  static const Color breakfastTile = Color(0xFFFFF5EB);
  static const Color lunchTile = Color(0xFFFEF9E7);
  static const Color snacksTile = Color(0xFFFFF1E6);
  static const Color dinnerTile = Color(0xFFEFF6FF);
}

class ThaliTheme {
  ThaliTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Urbanist',
        scaffoldBackgroundColor: ThaliColors.scaffold,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThaliColors.primary,
          primary: ThaliColors.primary,
          onPrimary: Colors.white,
          surface: ThaliColors.card,
          onSurface: ThaliColors.ink,
          error: ThaliColors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ThaliColors.card,
          foregroundColor: ThaliColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Urbanist',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ThaliColors.ink,
            letterSpacing: -0.2,
          ),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ThaliColors.ink, letterSpacing: -0.6),
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ThaliColors.ink, letterSpacing: -0.4),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ThaliColors.ink, letterSpacing: -0.2),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ThaliColors.body),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ThaliColors.body),
          bodySmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: ThaliColors.muted),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ThaliColors.card,
          hintStyle: const TextStyle(color: ThaliColors.hint, fontSize: 13.5, fontWeight: FontWeight.w500),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThaliColors.stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThaliColors.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThaliColors.primary, width: 1.6),
          ),
        ),
        dividerTheme: const DividerThemeData(color: ThaliColors.stroke, thickness: 1, space: 1),
      );
}
