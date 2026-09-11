import 'game.dart';

/// Outcome of one 30-second round.
class RoundResult {
  const RoundResult({
    required this.game,
    required this.difficulty,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.previousBest,
  });

  final GameId game;
  final Difficulty difficulty;
  final int score;
  final int correct;
  final int wrong;
  final int previousBest;

  bool get isNewBest => score > 0 && score > previousBest;

  int get improvement => isNewBest ? score - previousBest : 0;

  /// Whole-number percentage; 0 when nothing was attempted.
  int get accuracy {
    final attempts = correct + wrong;
    return attempts == 0 ? 0 : (correct * 100 / attempts).round();
  }
}
