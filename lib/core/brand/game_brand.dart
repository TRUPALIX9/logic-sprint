import 'package:flutter/material.dart';

import '../../models/game_model.dart';
import 'brand_palette.dart';

/// Per-mini-game visual identity layered on top of the master brand.
class GameBrand {
  const GameBrand({
    required this.type,
    required this.label,
    required this.accent,
    required this.secondary,
    required this.gradient,
    required this.iconBackground,
  });

  final GameType type;
  final String label;
  final Color accent;
  final Color secondary;
  final LinearGradient gradient;
  final Color iconBackground;

  static GameBrand forGame(GameType type) {
    switch (type) {
      case GameType.quickMath:
        return quickMath;
      case GameType.colorSequence:
        return colorSequence;
      case GameType.emojiMatch:
        return emojiMatch;
      case GameType.patternLock:
        return patternLock;
      case GameType.launchRocket:
        return launchRocket;
      case GameType.trueFalse:
        return trueFalse;
    }
  }

  static const quickMath = GameBrand(
    type: GameType.quickMath,
    label: 'Quick Math',
    accent: BrandPalette.electricBlue,
    secondary: BrandPalette.brainCyan,
    gradient: LinearGradient(
      colors: [BrandPalette.deepPurple, BrandPalette.electricBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3310BDEB),
  );

  static const colorSequence = GameBrand(
    type: GameType.colorSequence,
    label: 'Color Sequence',
    accent: BrandPalette.energyOrange,
    secondary: BrandPalette.brainCyan,
    gradient: LinearGradient(
      colors: [
        BrandPalette.energyOrange,
        BrandPalette.brainCyan,
        BrandPalette.electricBlue,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x33FF8A00),
  );

  static const emojiMatch = GameBrand(
    type: GameType.emojiMatch,
    label: 'Emoji Match',
    accent: BrandPalette.brainCyan,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.electricBlue, BrandPalette.brainCyan],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3345D7FF),
  );

  static const patternLock = GameBrand(
    type: GameType.patternLock,
    label: 'Pattern Lock',
    accent: BrandPalette.deepPurple,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.primaryNavy, BrandPalette.deepPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3325105A),
  );

  static const launchRocket = GameBrand(
    type: GameType.launchRocket,
    label: 'Launch Rocket',
    accent: BrandPalette.energyOrange,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [Color(0xFF1A1245), BrandPalette.primaryNavy, Color(0xFF0D3A6E)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    iconBackground: Color(0x33FF8A00),
  );

  static const trueFalse = GameBrand(
    type: GameType.trueFalse,
    label: 'True or False',
    accent: BrandPalette.successGreen,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.successGreen, BrandPalette.electricBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3322C55E),
  );
}
