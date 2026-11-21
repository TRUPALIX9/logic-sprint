import 'game.dart';
import 'run_record.dart';

/// One game's line on Profile and on the shared image.
class GameStat {
  const GameStat({
    required this.game,
    required this.best,
    required this.runs,
    this.bests = const {},
    this.difficulty,
    this.bestTime,
    this.rank,
  });

  final GameId game;

  /// Highest score across difficulties (0 = not played / no score yet).
  final int best;

  /// Where [best] was set; null for ramp games (one mode only).
  final Difficulty? difficulty;

  /// Best per difficulty, for games that have them (empty for ramp games).
  final Map<Difficulty, int> bests;

  /// Runs finished, all difficulties. Not shown for now.
  final int runs;

  /// How long the best run took (timed games only).
  final Duration? bestTime;

  /// The player's rank on the board of [best], when known.
  final int? rank;

  bool get hasBest => best > 0;
}

/// Everything the Profile stats card and the share image show. Built from
/// local data only; nothing here is made up.
class ProfileStats {
  const ProfileStats({
    required this.games,
    required this.runs,
    required this.played,
    required this.playedIsPartial,
    this.name,
    this.tag,
    this.sprintTop,
  });

  /// Reads bests, play counts and cached ranks through the callbacks so this
  /// stays free of Flutter/state imports (and easy to test).
  factory ProfileStats.from({
    required String? name,
    required String? tag,
    required int Function(GameId, Difficulty) best,
    required Duration? Function(GameId, Difficulty) bestTime,
    required int Function(GameId, Difficulty) plays,
    required int? Function(GameId, Difficulty) rank,
    required List<RunRecord> history,
    int? sprintTop,
  }) {
    final games = <GameStat>[];
    for (final game in GameId.values) {
      final difficulties = game.hasDifficulty
          ? Difficulty.values
          : const [GameId.rampDifficulty];
      var top = difficulties.first;
      for (final d in difficulties) {
        // Ties go to the harder difficulty (later in the list).
        if (best(game, d) >= best(game, top)) {
          top = d;
        }
      }
      final score = best(game, top);
      games.add(
        GameStat(
          game: game,
          best: score,
          bests: game.hasDifficulty
              ? {for (final d in difficulties) d: best(game, d)}
              : const {},
          difficulty: game.hasDifficulty && score > 0 ? top : null,
          runs: difficulties.fold(0, (sum, d) => sum + plays(game, d)),
          bestTime: game.tracksTime && score > 0 ? bestTime(game, top) : null,
          rank: score > 0 ? rank(game, top) : null,
        ),
      );
    }
    final runs = games.fold(0, (sum, g) => sum + g.runs);
    return ProfileStats(
      name: name,
      tag: tag,
      games: games,
      runs: runs,
      played: history.fold(Duration.zero, (sum, r) => sum + r.duration),
      // History keeps the latest runs only, so older time isn't counted.
      playedIsPartial: history.length < runs,
      sprintTop: sprintTop,
    );
  }

  /// Display name without the tag; null until set.
  final String? name;

  /// The 4-digit code ("0420"), once known.
  final String? tag;

  /// Sprint Score as "top X percent" (1–100) from `my_rating()`; null until
  /// the player and 50+ others are rated. Only Top 20% or better is shown as
  /// a number; see [SprintLevel].
  final int? sprintTop;

  final List<GameStat> games;

  /// Runs finished on this device, all games. Not shown for now.
  final int runs;

  /// Total time in the runs History still holds.
  final Duration played;

  /// [played] covers only part of [runs] (History is capped).
  final bool playedIsPartial;

  bool get hasAnyBest => games.any((g) => g.hasBest);
}

/// "3h 12m", "12m", "45s"; "0m" for nothing.
String formatPlayed(Duration played) {
  final hours = played.inHours;
  final minutes = played.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  final seconds = played.inSeconds;
  return seconds > 0 ? '${seconds}s' : '0m';
}

/// "1,234" — bests are shown with thousands separators.
String formatScore(int score) {
  final digits = '$score';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(',');
    }
    out.write(digits[i]);
  }
  return out.toString();
}
