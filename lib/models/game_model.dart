import 'package:flutter/material.dart';

import '../core/brand/game_brand.dart';

enum GameType {
  quickMath,
  colorSequence,
  emojiMatch,
  patternLock,
  launchRocket,
  trueFalse,
}

enum DifficultyLevel { easy, medium, hard }

class GameModel {
  const GameModel({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.emoji,
    this.skipsDifficulty = false,
  });

  final GameType type;
  final String title;
  final String description;
  final IconData icon;
  final String? emoji;
  final bool skipsDifficulty;

  Color get accentColor => type.accentColor;
}

extension GameTypeX on GameType {
  String get title {
    switch (this) {
      case GameType.quickMath:
        return 'Quick Math';
      case GameType.colorSequence:
        return 'Color Sequence';
      case GameType.emojiMatch:
        return 'Emoji Match';
      case GameType.patternLock:
        return 'Pattern Lock';
      case GameType.launchRocket:
        return 'Launch Rocket';
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
      case GameType.emojiMatch:
        return 'Flip cards and match all emoji pairs before time runs out.';
      case GameType.patternLock:
        return 'Memorize the dot pattern and recreate it from memory.';
      case GameType.launchRocket:
        return 'Dodge asteroids in space.';
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
      case GameType.emojiMatch:
        return Icons.emoji_emotions_rounded;
      case GameType.patternLock:
        return Icons.pattern_rounded;
      case GameType.launchRocket:
        return Icons.rocket_launch_rounded;
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
      case GameType.emojiMatch:
        return 'emojiMatch';
      case GameType.patternLock:
        return 'patternLock';
      case GameType.launchRocket:
        return 'launchRocket';
      case GameType.trueFalse:
        return 'trueFalse';
    }
  }

  bool get isPlayable {
    switch (this) {
      case GameType.quickMath:
      case GameType.colorSequence:
      case GameType.emojiMatch:
      case GameType.patternLock:
      case GameType.launchRocket:
      case GameType.trueFalse:
        return true;
    }
  }

  bool get usesDifficulty {
    return this != GameType.launchRocket;
  }

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

/// Games shown on the home launcher (wireframe order).
const List<GameModel> homeLauncherGames = [
  GameModel(
    type: GameType.quickMath,
    title: 'Quick Math',
    description: 'Solve fast arithmetic',
    icon: Icons.calculate_rounded,
    emoji: '🧠',
  ),
  GameModel(
    type: GameType.colorSequence,
    title: 'Color Sequence',
    description: 'Watch and repeat colors',
    icon: Icons.palette_rounded,
    emoji: '🎨',
  ),
  GameModel(
    type: GameType.emojiMatch,
    title: 'Emoji Match',
    description: 'Match emoji pairs',
    icon: Icons.emoji_emotions_rounded,
    emoji: '🧩',
  ),
  GameModel(
    type: GameType.patternLock,
    title: 'Pattern Lock',
    description: 'Remember the unlock path',
    icon: Icons.pattern_rounded,
    emoji: '🔐',
  ),
  GameModel(
    type: GameType.launchRocket,
    title: 'Launch Rocket',
    description: 'Dodge asteroids in space',
    icon: Icons.rocket_launch_rounded,
    emoji: '🚀',
    skipsDifficulty: true,
  ),
];

const List<GameModel> availableGames = [
  ...homeLauncherGames,
  GameModel(
    type: GameType.trueFalse,
    title: 'True or False',
    description: 'Answer rapid-fire facts as true or false.',
    icon: Icons.fact_check_rounded,
  ),
];
