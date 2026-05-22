import 'package:flutter/material.dart';

import '../core/brand/game_brand.dart';

enum GameType {
  quickMath,
  colorSequence,
  trueFalse,
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
      case GameType.quickMath:
        return 'Quick Math';
      case GameType.colorSequence:
        return 'Color Sequence';
      case GameType.trueFalse:
        return 'True or False';
    }
  }

  String get description {
    switch (this) {
      case GameType.quickMath:
        return 'Solve fast arithmetic before the clock runs out.';
      case GameType.colorSequence:
        return 'Watch the pattern and repeat the colors.';
      case GameType.trueFalse:
        return 'Sort rapid-fire facts into true or false.';
    }
  }

  IconData get icon {
    switch (this) {
      case GameType.quickMath:
        return Icons.calculate_rounded;
      case GameType.colorSequence:
        return Icons.palette_rounded;
      case GameType.trueFalse:
        return Icons.fact_check_rounded;
    }
  }

  String get storageKey {
    switch (this) {
      case GameType.quickMath:
        return 'quickMath';
      case GameType.colorSequence:
        return 'colorSequence';
      case GameType.trueFalse:
        return 'trueFalse';
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
        return 'Warm up with shorter patterns.';
      case DifficultyLevel.medium:
        return 'Mix speed with longer sequences.';
      case DifficultyLevel.hard:
        return 'Handle the longest memory challenges.';
    }
  }
}

const List<GameModel> availableGames = [
  GameModel(
    type: GameType.quickMath,
    title: 'Quick Math',
    description: 'Solve fast arithmetic before time runs out.',
    icon: Icons.calculate_rounded,
  ),
  GameModel(
    type: GameType.colorSequence,
    title: 'Color Sequence',
    description: 'Watch the pattern and repeat the colors.',
    icon: Icons.palette_rounded,
  ),
  GameModel(
    type: GameType.trueFalse,
    title: 'True or False',
    description: 'Answer rapid-fire facts as true or false.',
    icon: Icons.fact_check_rounded,
  ),
];
