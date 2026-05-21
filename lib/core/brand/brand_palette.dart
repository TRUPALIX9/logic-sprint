import 'package:flutter/material.dart';

/// Colors from [BrandAssets.brandTokens] (`assets/brand/tokens/brand_tokens.json`).
abstract final class BrandPalette {
  static const Color midnightPurple = Color(0xFF12002F);
  static const Color deepBlue = Color(0xFF004F9F);
  static const Color electricBlue = Color(0xFF23BEEF);
  static const Color sprintOrange = Color(0xFFFC8620);
  static const Color softIce = Color(0xFFD8E5EC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF130A33);

  static const Color surfaceLight = softIce;
  static const Color surfaceDark = midnightPurple;
  static const Color cardDark = Color(0xFF1A0A3D);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [midnightPurple, deepBlue, electricBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [midnightPurple, deepBlue, Color(0xFF0066B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [sprintOrange, Color(0xFFFF9A3C)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
