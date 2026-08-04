import 'package:flutter/material.dart';

import '../core/brand/game_brand.dart';

enum GameType {
  rocketLaunch,
  memoryLane,
}

enum DifficultyLevel { easy, medium, hard }

class GameModel {
  const GameModel({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });

  final GameType type;
  final String title;
  final String description;
  final IconData icon;

  Color get accentColor => type.accentColor;
}

extension GameTypeX on GameType {
  String get title {
    switch (this) {
      case GameType.rocketLaunch:
        return 'Rocket Launch';
      case GameType.memoryLane:
        return 'Memory Lane';
    }
  }

  String get description {
    switch (this) {
      case GameType.rocketLaunch:
        return 'Dodge incoming asteroids to navigate your rocket ship through space.';
      case GameType.memoryLane:
        return 'Watch sequentially flashing blocks and repeat the exact order.';
    }
  }

  IconData get icon {
    switch (this) {
      case GameType.rocketLaunch:
        return Icons.rocket_launch_rounded;
      case GameType.memoryLane:
        return Icons.grid_on_rounded;
    }
  }

  String get storageKey {
    switch (this) {
      case GameType.rocketLaunch:
        return 'rocketLaunch';
      case GameType.memoryLane:
        return 'memoryLane';
    }
  }

  bool get isPlayable => true;

  Color get accentColor => GameBrand.forGame(this).accent;
}

extension DifficultyLevelX on DifficultyLevel {
  String get title {
    switch (this) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  String get storageKey {
    switch (this) {
      case DifficultyLevel.easy:
        return 'easy';
      case DifficultyLevel.medium:
        return 'medium';
      case DifficultyLevel.hard:
        return 'hard';
    }
  }

  String get shortHint {
    switch (this) {
      case DifficultyLevel.easy:
        return 'Start slow with manageable challenges.';
      case DifficultyLevel.medium:
        return 'Speed increases and patterns lengthen.';
      case DifficultyLevel.hard:
        return 'Maximum speed and expert sequences.';
    }
  }
}

const List<GameModel> availableGames = [
  GameModel(
    type: GameType.rocketLaunch,
    title: 'Rocket Launch',
    description: 'Dodge incoming asteroids to navigate your rocket ship through space.',
    icon: Icons.rocket_launch_rounded,
  ),
  GameModel(
    type: GameType.memoryLane,
    title: 'Memory Lane',
    description: 'Watch sequentially flashing blocks and repeat the exact order.',
    icon: Icons.grid_on_rounded,
  ),
];
