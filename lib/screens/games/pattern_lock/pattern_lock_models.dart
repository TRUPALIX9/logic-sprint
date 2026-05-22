import '../../../models/game_model.dart';

class PatternLockConfig {
  const PatternLockConfig({
    required this.gridSize,
    required this.startingLength,
    required this.maxLength,
    required this.previewDuration,
    required this.lives,
  });

  final int gridSize;
  final int startingLength;
  final int maxLength;
  final Duration previewDuration;
  final int lives;
}

PatternLockConfig patternLockConfigFor(DifficultyLevel difficulty) {
  switch (difficulty) {
    case DifficultyLevel.easy:
      return const PatternLockConfig(
        gridSize: 3,
        startingLength: 3,
        maxLength: 6,
        previewDuration: Duration(milliseconds: 1500),
        lives: 3,
      );
    case DifficultyLevel.medium:
      return const PatternLockConfig(
        gridSize: 3,
        startingLength: 4,
        maxLength: 7,
        previewDuration: Duration(milliseconds: 1100),
        lives: 2,
      );
    case DifficultyLevel.hard:
      return const PatternLockConfig(
        gridSize: 3,
        startingLength: 5,
        maxLength: 9,
        previewDuration: Duration(milliseconds: 800),
        lives: 1,
      );
  }
}
