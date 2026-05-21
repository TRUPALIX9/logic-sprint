import 'package:flutter/material.dart';

enum GameType {
  quickMath,
  numberSequence,
  trueFalse,
  memoryPattern,
  colorConfusion,
}

enum DifficultyLevel { easy, medium, hard }

class GameModel {
  const GameModel({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.isComingSoon = false,
  });

  final GameType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isComingSoon;
}

extension GameTypeX on GameType {
  String get title {
    switch (this) {
      case GameType.quickMath:
        return 'Quick Math';
      case GameType.numberSequence:
        return 'Number Sequence';
      case GameType.trueFalse:
        return 'True or False';
      case GameType.memoryPattern:
        return 'Memory Pattern';
      case GameType.colorConfusion:
        return 'Color Confusion';
    }
  }

  String get description {
    switch (this) {
      case GameType.quickMath:
        return 'Solve fast arithmetic before the clock runs out.';
      case GameType.numberSequence:
        return 'Spot the pattern and pick the missing next number.';
      case GameType.trueFalse:
        return 'Judge quick facts about math, shapes, and numbers.';
      case GameType.memoryPattern:
        return 'Repeat visual sequences once this mode launches.';
      case GameType.colorConfusion:
        return 'Stay sharp through tricky color-word clashes.';
    }
  }

  IconData get icon {
    switch (this) {
      case GameType.quickMath:
        return Icons.calculate_rounded;
      case GameType.numberSequence:
        return Icons.auto_graph_rounded;
      case GameType.trueFalse:
        return Icons.fact_check_rounded;
      case GameType.memoryPattern:
        return Icons.grid_view_rounded;
      case GameType.colorConfusion:
        return Icons.palette_rounded;
    }
  }

  String get storageKey {
    switch (this) {
      case GameType.quickMath:
        return 'quickMath';
      case GameType.numberSequence:
        return 'numberSequence';
      case GameType.trueFalse:
        return 'trueFalse';
      case GameType.memoryPattern:
        return 'memoryPattern';
      case GameType.colorConfusion:
        return 'colorConfusion';
    }
  }

  bool get isPlayable {
    switch (this) {
      case GameType.quickMath:
      case GameType.numberSequence:
      case GameType.trueFalse:
        return true;
      case GameType.memoryPattern:
      case GameType.colorConfusion:
        return false;
    }
  }
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
        return 'Warm up with steady patterns.';
      case DifficultyLevel.medium:
        return 'Mix speed with sharper thinking.';
      case DifficultyLevel.hard:
        return 'Handle the fastest logic challenges.';
    }
  }
}

const List<GameModel> availableGames = [
  GameModel(
    type: GameType.quickMath,
    title: 'Quick Math',
    description: 'Solve fast arithmetic before the timer hits zero.',
    icon: Icons.calculate_rounded,
  ),
  GameModel(
    type: GameType.numberSequence,
    title: 'Number Sequence',
    description: 'Find the pattern and pick the next number.',
    icon: Icons.auto_graph_rounded,
  ),
  GameModel(
    type: GameType.trueFalse,
    title: 'True or False',
    description: 'Sort rapid-fire facts into true or false.',
    icon: Icons.fact_check_rounded,
  ),
  GameModel(
    type: GameType.memoryPattern,
    title: 'Memory Pattern',
    description: 'Coming soon',
    icon: Icons.grid_view_rounded,
    isComingSoon: true,
  ),
  GameModel(
    type: GameType.colorConfusion,
    title: 'Color Confusion',
    description: 'Coming soon',
    icon: Icons.palette_rounded,
    isComingSoon: true,
  ),
];
