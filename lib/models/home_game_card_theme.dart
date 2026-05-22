import 'package:flutter/material.dart';

import 'game_model.dart';

class HomeGameCardTheme {
  const HomeGameCardTheme({
    required this.gradient,
    required this.accent,
    required this.iconBackground,
    required this.glow,
  });

  final List<Color> gradient;
  final Color accent;
  final Color iconBackground;
  final Color glow;

  static HomeGameCardTheme forGame(GameType type) {
    switch (type) {
      case GameType.quickMath:
        return const HomeGameCardTheme(
          gradient: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
          accent: Color(0xFF67E8F9),
          iconBackground: Color(0xFF0369A1),
          glow: Color(0xFF22D3EE),
        );
      case GameType.colorSequence:
        return const HomeGameCardTheme(
          gradient: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          accent: Color(0xFFF472B6),
          iconBackground: Color(0xFF5B21B6),
          glow: Color(0xFFC026D3),
        );
      case GameType.emojiMatch:
        return const HomeGameCardTheme(
          gradient: [Color(0xFF059669), Color(0xFF0D9488)],
          accent: Color(0xFF6EE7B7),
          iconBackground: Color(0xFF047857),
          glow: Color(0xFF2DD4BF),
        );
      case GameType.patternLock:
        return const HomeGameCardTheme(
          gradient: [Color(0xFF4338CA), Color(0xFF5B21B6)],
          accent: Color(0xFFC4B5FD),
          iconBackground: Color(0xFF3730A3),
          glow: Color(0xFF818CF8),
        );
      case GameType.launchRocket:
        return const HomeGameCardTheme(
          gradient: [Color(0xFF1E3A5F), Color(0xFFEA580C)],
          accent: Color(0xFFFFB347),
          iconBackground: Color(0xFF9A3412),
          glow: Color(0xFFF97316),
        );
      case GameType.trueFalse:
        return const HomeGameCardTheme(
          gradient: [Color(0xFF334155), Color(0xFF64748B)],
          accent: Color(0xFF94A3B8),
          iconBackground: Color(0xFF1E293B),
          glow: Color(0xFF64748B),
        );
    }
  }
}
