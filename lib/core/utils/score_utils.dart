abstract final class ScoreUtils {
  static const int roundLengthSeconds = 30;
  static const int correctAnswerPoints = 10;
  static const int streakBonusEvery = 5;
  static const int streakBonusPoints = 20;

  static double accuracyPercentage({
    required int correctAnswers,
    required int wrongAnswers,
  }) {
    final total = correctAnswers + wrongAnswers;
    if (total == 0) {
      return 0;
    }
    return (correctAnswers / total) * 100;
  }
}
