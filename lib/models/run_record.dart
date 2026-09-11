import 'game.dart';
import 'round_result.dart';

/// One finished run, kept in the local History (and queued for the server
/// until it syncs).
class RunRecord {
  const RunRecord({
    required this.game,
    required this.difficulty,
    required this.score,
    required this.duration,
    required this.playedAt,
    this.isBest = false,
  });

  factory RunRecord.fromResult(RoundResult result, DateTime playedAt) =>
      RunRecord(
        game: result.game,
        difficulty: result.difficulty,
        score: result.score,
        duration: result.duration,
        playedAt: playedAt,
        isBest: result.isNewBest,
      );

  final GameId game;
  final Difficulty difficulty;
  final int score;
  final Duration duration;
  final DateTime playedAt;

  /// This run set a new personal best.
  final bool isBest;

  /// Null for games or difficulties this build doesn't know.
  static RunRecord? fromJson(Map<String, dynamic> json) {
    final game = GameId.tryParse('${json['game']}');
    final difficulty = Difficulty.values
        .where((d) => d.name == json['difficulty'])
        .firstOrNull;
    if (game == null || difficulty == null) {
      return null;
    }
    return RunRecord(
      game: game,
      difficulty: difficulty,
      score: (json['score'] as num?)?.toInt() ?? 0,
      duration: Duration(
        milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
      ),
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['at'] as num?)?.toInt() ?? 0,
      ),
      isBest: json['best'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'game': game.name,
    'difficulty': difficulty.name,
    'score': score,
    'durationMs': duration.inMilliseconds,
    'at': playedAt.millisecondsSinceEpoch,
    'best': isBest,
  };
}
