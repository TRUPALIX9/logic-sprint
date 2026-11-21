import 'game.dart';
import 'run_record.dart';

/// Order of the runs on the History page.
enum HistorySort {
  newest('Newest'),
  oldest('Oldest'),
  highest('Highest score'),
  lowest('Lowest score');

  const HistorySort(this.label);

  final String label;
}

/// What the History page shows: an optional game (and, for games with
/// difficulty, an optional difficulty) in one sort order. Pure Dart, so it
/// is tested apart from the UI.
class HistoryQuery {
  const HistoryQuery({
    this.game,
    this.difficulty,
    this.sort = HistorySort.newest,
  });

  /// Null for every game.
  final GameId? game;

  /// Null for every difficulty. Only used with a [game] that has them.
  final Difficulty? difficulty;

  final HistorySort sort;

  /// Picking a game clears the difficulty; picking the same one again does
  /// nothing.
  HistoryQuery withGame(GameId? game) =>
      game == this.game ? this : HistoryQuery(game: game, sort: sort);

  HistoryQuery withDifficulty(Difficulty? difficulty) =>
      HistoryQuery(game: game, difficulty: difficulty, sort: sort);

  HistoryQuery withSort(HistorySort sort) =>
      HistoryQuery(game: game, difficulty: difficulty, sort: sort);

  bool matches(RunRecord run) {
    final game = this.game;
    if (game == null) {
      return true;
    }
    if (run.game != game) {
      return false;
    }
    final difficulty = this.difficulty;
    return difficulty == null ||
        !game.hasDifficulty ||
        run.difficulty == difficulty;
  }

  /// The matching runs of [history] (newest first, as stored) in [sort]
  /// order. Equal scores keep the newer run first; equal times keep the
  /// stored order.
  List<RunRecord> apply(List<RunRecord> history) {
    final runs = [
      for (final (i, run) in history.indexed)
        if (matches(run)) (i, run),
    ];
    int compare((int, RunRecord) a, (int, RunRecord) b) {
      final (ai, ar) = a;
      final (bi, br) = b;
      final primary = switch (sort) {
        HistorySort.newest => br.playedAt.compareTo(ar.playedAt),
        HistorySort.oldest => ar.playedAt.compareTo(br.playedAt),
        HistorySort.highest => br.score.compareTo(ar.score),
        HistorySort.lowest => ar.score.compareTo(br.score),
      };
      if (primary != 0) {
        return primary;
      }
      final byTime = sort == HistorySort.oldest
          ? 0
          : br.playedAt.compareTo(ar.playedAt);
      if (byTime != 0) {
        return byTime;
      }
      return sort == HistorySort.oldest ? bi.compareTo(ai) : ai.compareTo(bi);
    }

    runs.sort(compare);
    return [for (final (_, run) in runs) run];
  }
}
