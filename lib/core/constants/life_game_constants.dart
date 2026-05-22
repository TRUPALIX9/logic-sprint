import '../../models/game_model.dart';

/// Shared life-based gameplay defaults.
abstract final class LifeGameConstants {
  static const int startingLives = 3;
  static const DifficultyLevel storageDifficulty = DifficultyLevel.easy;
}
