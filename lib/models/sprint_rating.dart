import 'game.dart';

/// The Sprint Score maths, step for step the same as the `player_ratings`
/// view in supabase/schema.sql (design/plans/upgrades_plan.html, D). The app
/// gets the result from `my_rating()`; this pure copy pins the formula in
/// unit tests so the SQL and the plan can't drift apart unnoticed.
abstract final class SprintRating {
  /// A board counts only with this many players (fewer gives jumpy ranks).
  static const minBoardPlayers = 30;

  /// A game counts once the player has this many runs in it.
  static const minGameRuns = 3;

  /// A player is rated with this many counted games.
  static const minRatedGames = 2;

  /// "Top X%" is shown only once this many players are rated.
  static const minRatedPlayers = 50;

  /// Shrinkage: [priorGames] imaginary games at [prior] pull one lucky
  /// spike toward the middle.
  static const prior = 50.0;
  static const priorGames = 2;

  /// "Top X%" steps; rounding up to one of these never overclaims.
  static const topBuckets = [
    1,
    2,
    5,
    10,
    15,
    20,
    25,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  /// Percentile on one board: 100 × (below + ½ × tied) ÷ players.
  static double percentile({
    required int better,
    required int tied,
    required int players,
  }) => 100 * (players - better - tied + 0.5 * tied) / players;

  /// Highest board percentile a difficulty can give: Hard is the only way
  /// to the very top. Games without levels aren't capped.
  static double cap(GameId game, Difficulty difficulty) {
    if (!game.hasDifficulty) {
      return 100;
    }
    return switch (difficulty) {
      Difficulty.easy => 90,
      Difficulty.medium => 97,
      Difficulty.hard => 100,
    };
  }

  /// Percentile of every player on one board, from (player, score, tieKey)
  /// rows: higher score wins, then lower tieKey (the run time for Memory
  /// Lane and Quick Math, when the best was set for the rest), so equal
  /// scores still get their own places. Scores of 0 are left out: they
  /// aren't on the boards and would only pile up as one big tie. Empty
  /// below [minBoardPlayers] scoring players.
  static Map<String, double> board(
    GameId game,
    Difficulty difficulty,
    List<({String player, int score, int tieKey})> all,
  ) {
    final rows = [
      for (final row in all)
        if (row.score > 0) row,
    ];
    if (rows.length < minBoardPlayers) {
      return const {};
    }
    bool beats(
      ({String player, int score, int tieKey}) a,
      ({String player, int score, int tieKey}) b,
    ) => a.score > b.score || (a.score == b.score && a.tieKey < b.tieKey);
    final limit = cap(game, difficulty);
    return {
      for (final me in rows)
        me.player: percentile(
          better: rows.where((o) => beats(o, me)).length,
          tied: rows
              .where((o) => o.score == me.score && o.tieKey == me.tieKey)
              .length,
          players: rows.length,
        ).clamp(0, limit).toDouble(),
    };
  }

  /// R = (p₁ + … + pₙ + 2 × 50) ÷ (n + 2) over the player's counted games.
  static double combine(Iterable<double> games) {
    final list = games.toList();
    return (list.fold(0.0, (sum, p) => sum + p) + prior * priorGames) /
        (list.length + priorGames);
  }

  /// Each rated player's rating: their R's percentile among rated players.
  static Map<String, double> ratings(Map<String, double> combined) => {
    for (final MapEntry(key: player, value: r) in combined.entries)
      player: percentile(
        better: combined.values.where((o) => o > r).length,
        tied: combined.values.where((o) => o == r).length,
        players: combined.length,
      ),
  };

  /// "Top X%" for a rating, rounded up to a [topBuckets] step (plain
  /// rounding up beyond the last step).
  static int top(double rating) {
    final raw = (100 - rating).ceil();
    for (final bucket in topBuckets) {
      if (bucket >= raw) {
        return bucket;
      }
    }
    return raw;
  }
}
