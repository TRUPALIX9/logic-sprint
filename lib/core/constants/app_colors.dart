import 'package:flutter/material.dart';

import '../brand/brand_palette.dart';

abstract final class AppColors {
  static const Color primary = BrandPalette.electricBlue;
  static const Color primaryDark = BrandPalette.primaryNavy;
  static const Color accent = BrandPalette.energyOrange;
  static const Color success = BrandPalette.successGreen;
  static const Color danger = BrandPalette.errorRed;
  static const Color surfaceLight = BrandPalette.softBackground;
  static const Color surfaceDark = BrandPalette.surfaceDark;
  static const Color cardDark = BrandPalette.cardDark;
  static const Color cardLight = BrandPalette.cardWhite;
  static const Color textDark = BrandPalette.textDark;
  static const Color textMuted = BrandPalette.mutedText;
  static const Color brainCyan = BrandPalette.brainCyan;
}
