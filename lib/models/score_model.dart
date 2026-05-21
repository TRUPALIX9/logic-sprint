import 'game_model.dart';

class ScoreModel {
  const ScoreModel({
    required this.gameType,
    required this.difficulty,
    required this.finalScore,
    required this.bestScore,
    required this.previousBestScore,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.accuracyPercentage,
  });

  final GameType gameType;
  final DifficultyLevel difficulty;
  final int finalScore;
  final int bestScore;
  final int previousBestScore;
  final int correctAnswers;
  final int wrongAnswers;
  final double accuracyPercentage;

  bool get isNewBest => finalScore > previousBestScore;
}
