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
    this.level = 1,
    this.usedSecondLife = false,
  });

  final GameType gameType;
  final DifficultyLevel difficulty;
  final int finalScore;
  final int bestScore;
  final int previousBestScore;
  final int correctAnswers;
  final int wrongAnswers;
  final double accuracyPercentage;
  final int level;
  final bool usedSecondLife;

  bool get isNewBest => finalScore > previousBestScore;

  Map<String, dynamic> toHistoryJson() {
    return {
      'gameType': gameType.storageKey,
      'finalScore': finalScore,
      'level': level,
      'usedSecondLife': usedSecondLife,
      'recordedAt': DateTime.now().toIso8601String(),
    };
  }
}
