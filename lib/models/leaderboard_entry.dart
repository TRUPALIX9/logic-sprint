import 'game.dart';

/// One row of a global Top 10 (the `leaderboard_top` view in Supabase): a
/// player's best on one game and difficulty.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.score,
    required this.game,
    required this.difficulty,
    this.duration,
    this.bestAt,
  });

  final String playerId;
  final String playerName;
  final int score;
  final GameId game;
  final Difficulty difficulty;

  /// How long the best run took (older rows may not have it).
  final Duration? duration;
  final DateTime? bestAt;

  /// Parses a view row; returns null for games or difficulties this build
  /// doesn't know.
  static LeaderboardEntry? fromRow(Map<String, dynamic> row) {
    final game = GameId.tryParse('${row['game_type']}');
    final difficulty = Difficulty.values
        .where((d) => d.name == row['difficulty'])
        .firstOrNull;
    if (game == null || difficulty == null) {
      return null;
    }
    return LeaderboardEntry(
      playerId: '${row['player_id'] ?? ''}',
      playerName: '${row['player_name'] ?? 'Player'}',
      score: (row['score'] as num?)?.toInt() ?? 0,
      game: game,
      difficulty: difficulty,
      duration: row['duration_ms'] is num
          ? Duration(milliseconds: (row['duration_ms'] as num).toInt())
          : null,
      bestAt: DateTime.tryParse('${row['best_at'] ?? ''}'),
    );
  }

  /// Same shape as the view row, so the cache round-trips via [fromRow].
  Map<String, dynamic> toRow() => {
    'player_id': playerId,
    'player_name': playerName,
    'score': score,
    'game_type': game.name,
    'difficulty': difficulty.name,
    'duration_ms': duration?.inMilliseconds,
    'best_at': bestAt?.toIso8601String(),
  };
}
