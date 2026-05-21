import 'package:flutter/material.dart';

/// LogicSprint brand palette for v1 UI.
abstract final class BrandPalette {
  static const Color primaryNavy = Color(0xFF120A3D);
  static const Color deepPurple = Color(0xFF25105A);
  static const Color electricBlue = Color(0xFF10BDEB);
  static const Color brainCyan = Color(0xFF45D7FF);
  static const Color energyOrange = Color(0xFFFF8A00);
  static const Color softBackground = Color(0xFFF3FAFD);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1F2933);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFEF4444);

  static const Color surfaceLight = softBackground;
  static const Color surfaceDark = Color(0xFF0D0828);
  static const Color cardDark = Color(0xFF1A1245);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryNavy, deepPurple, Color(0xFF1A3A6E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [primaryNavy, deepPurple, Color(0xFF103878)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [energyOrange, Color(0xFFFFA94D)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
