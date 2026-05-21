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
      case GameType.numberSequence:
        return numberSequence;
      case GameType.trueFalse:
        return trueFalse;
      case GameType.memoryPattern:
        return memoryPattern;
      case GameType.colorConfusion:
        return colorConfusion;
    }
  }

  /// Logic blue + calculator energy (brand kit Quick Math tile).
  static const quickMath = GameBrand(
    type: GameType.quickMath,
    label: 'Quick Math',
    accent: BrandPalette.electricBlue,
    secondary: BrandPalette.deepBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.deepBlue, BrandPalette.electricBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3323BEEF),
  );

  /// Blue sequence line + orange progression arrow.
  static const numberSequence = GameBrand(
    type: GameType.numberSequence,
    label: 'Number Sequence',
    accent: BrandPalette.sprintOrange,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.deepBlue, BrandPalette.electricBlue, BrandPalette.sprintOrange],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x33FC8620),
  );

  /// Orange statement cards + lightning decisiveness.
  static const trueFalse = GameBrand(
    type: GameType.trueFalse,
    label: 'True or False',
    accent: BrandPalette.sprintOrange,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.sprintOrange, Color(0xFFFF9A3C), BrandPalette.electricBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x33FC8620),
  );

  /// Future game placeholder — purple memory motif.
  static const memoryPattern = GameBrand(
    type: GameType.memoryPattern,
    label: 'Memory Pattern',
    accent: BrandPalette.midnightPurple,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.midnightPurple, BrandPalette.deepBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3312002F),
  );

  /// Future game placeholder — contrast motif.
  static const colorConfusion = GameBrand(
    type: GameType.colorConfusion,
    label: 'Color Confusion',
    accent: BrandPalette.sprintOrange,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.sprintOrange, BrandPalette.electricBlue, BrandPalette.deepBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x33FC8620),
  );
}
