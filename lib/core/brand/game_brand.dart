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
      case GameType.rocketLaunch:
        return rocketLaunch;
      case GameType.memoryLane:
        return memoryLane;
    }
  }

  static const rocketLaunch = GameBrand(
    type: GameType.rocketLaunch,
    label: 'Rocket Launch',
    accent: BrandPalette.energyOrange,
    secondary: BrandPalette.electricBlue,
    gradient: LinearGradient(
      colors: [BrandPalette.deepPurple, BrandPalette.energyOrange],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x33FF8A00),
  );

  static const memoryLane = GameBrand(
    type: GameType.memoryLane,
    label: 'Memory Lane',
    accent: BrandPalette.electricBlue,
    secondary: BrandPalette.brainCyan,
    gradient: LinearGradient(
      colors: [BrandPalette.primaryNavy, BrandPalette.electricBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconBackground: Color(0x3310BDEB),
  );
}
