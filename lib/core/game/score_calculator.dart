/// Shared scoring rules for LogicSprint mini-games.
abstract final class ScoreCalculator {
  static int applyCorrect({
    required int currentScore,
    required int streakAfterCorrect,
  }) {
    var newScore = currentScore + 10;
    if (streakAfterCorrect > 0 && streakAfterCorrect % 5 == 0) {
      newScore += 20;
    }
    return newScore;
  }

  static int applyMismatchPenalty(int currentScore, {required int penalty}) {
    return currentScore > penalty ? currentScore - penalty : 0;
  }
}
