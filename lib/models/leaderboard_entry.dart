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

  LeaderboardEntry withName(String name) => LeaderboardEntry(
    playerId: playerId,
    playerName: name,
    score: score,
    game: game,
    difficulty: difficulty,
    duration: duration,
    bestAt: bestAt,
  );

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

/// How a player moved between two snapshots of the same board.
enum RankMoveKind { up, down, entered, same }

class RankMove {
  const RankMove(this.kind, {this.places = 0, this.from});

  final RankMoveKind kind;

  /// Places gained (up) or lost (down); 0 otherwise.
  final int places;

  /// The row they held before (0-based), or null for new entrants.
  final int? from;

  @override
  bool operator ==(Object other) =>
      other is RankMove &&
      other.kind == kind &&
      other.places == places &&
      other.from == from;

  @override
  int get hashCode => Object.hash(kind, places, from);

  @override
  String toString() => 'RankMove($kind, places: $places, from: $from)';
}

/// Movement of every player in [current] relative to [previous], keyed by
/// player id. Players who dropped off the board aren't included.
Map<String, RankMove> rankMoves(
  List<LeaderboardEntry> previous,
  List<LeaderboardEntry> current,
) {
  final before = {
    for (var i = previous.length - 1; i >= 0; i--) previous[i].playerId: i,
  };
  return {
    for (var i = 0; i < current.length; i++)
      current[i].playerId: switch (before[current[i].playerId]) {
        null => const RankMove(RankMoveKind.entered),
        final from when from > i => RankMove(
          RankMoveKind.up,
          places: from - i,
          from: from,
        ),
        final from when from < i => RankMove(
          RankMoveKind.down,
          places: i - from,
          from: from,
        ),
        final from => RankMove(RankMoveKind.same, from: from),
      },
  };
}

/// True when two snapshots rank the same players with the same scores.
bool sameStandings(List<LeaderboardEntry> a, List<LeaderboardEntry> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i].playerId != b[i].playerId || a[i].score != b[i].score) {
      return false;
    }
  }
  return true;
}
