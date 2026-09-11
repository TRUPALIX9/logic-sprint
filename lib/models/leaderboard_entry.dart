import 'game.dart';

/// One row of the global Top 10 (`leaderboard_scores` in Supabase).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.playerName,
    required this.score,
    required this.game,
    required this.difficulty,
    this.createdAt,
    this.duration,
  });

  final String id;
  final String playerName;
  final int score;
  final GameId game;
  final Difficulty difficulty;
  final DateTime? createdAt;

  /// How long the run took (older rows may not have it).
  final Duration? duration;

  /// Parses a Supabase row; returns null for games or difficulties this
  /// build doesn't know.
  static LeaderboardEntry? fromRow(Map<String, dynamic> row) {
    final game = GameId.tryParse('${row['game_type']}');
    final difficulty = Difficulty.values
        .where((d) => d.name == row['difficulty'])
        .firstOrNull;
    if (game == null || difficulty == null) {
      return null;
    }
    return LeaderboardEntry(
      id: '${row['id'] ?? ''}',
      playerName: '${row['player_name'] ?? 'Player'}',
      score: (row['score'] as num?)?.toInt() ?? 0,
      game: game,
      difficulty: difficulty,
      createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
      duration: row['duration_ms'] is num
          ? Duration(milliseconds: (row['duration_ms'] as num).toInt())
          : null,
    );
  }

  /// Same shape as the Supabase row, so the cache round-trips via [fromRow].
  Map<String, dynamic> toRow() => {
    'id': id,
    'player_name': playerName,
    'score': score,
    'game_type': game.name,
    'difficulty': difficulty.name,
    'created_at': createdAt?.toIso8601String(),
    'duration_ms': duration?.inMilliseconds,
  };
}
