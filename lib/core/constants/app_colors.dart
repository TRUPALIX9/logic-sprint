import 'package:flutter/material.dart';

import '../brand/brand_palette.dart';

abstract final class AppColors {
  static const Color primary = BrandPalette.electricBlue;
  static const Color primaryDark = BrandPalette.deepBlue;
  static const Color accent = BrandPalette.sprintOrange;
  static const Color success = Color(0xFF2AC769);
  static const Color danger = Color(0xFFF25555);
  static const Color surfaceLight = BrandPalette.surfaceLight;
  static const Color surfaceDark = BrandPalette.surfaceDark;
  static const Color cardDark = BrandPalette.cardDark;
  static const Color textMuted = Color(0xFF72809A);
}
