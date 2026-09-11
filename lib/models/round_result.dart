import 'game.dart';

/// Outcome of one endless run.
class RoundResult {
  const RoundResult({
    required this.game,
    required this.difficulty,
    required this.score,
    required this.correct,
    required this.duration,
    required this.previousBest,
  });

  final GameId game;
  final Difficulty difficulty;
  final int score;
  final int correct;

  /// How long the run lasted (time waiting on a revive excluded).
  final Duration duration;
  final int previousBest;

  bool get isNewBest => score > 0 && score > previousBest;

  int get improvement => isNewBest ? score - previousBest : 0;
}
