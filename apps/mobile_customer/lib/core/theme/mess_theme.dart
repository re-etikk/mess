import 'package:flutter/material.dart';
import 'thali_theme.dart';
export 'thali_theme.dart';

class MessColors {
  MessColors._();
  static const Color orange = ThaliColors.primary;
  static const Color orangeDark = ThaliColors.primaryDark;
  static const Color navy = ThaliColors.ink;
  static const Color cream = ThaliColors.scaffold;
  static const Color surface = ThaliColors.card;
  static const Color border = ThaliColors.stroke;
  static const Color muted = ThaliColors.muted;
  static const Color green = ThaliColors.green;
  static const Color amber = ThaliColors.amber;
  static const Color red = ThaliColors.red;
}

class MessTheme {
  MessTheme._();
  static ThemeData get light => ThaliTheme.light;
}
