import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/profile_stats.dart';

ProfileStats _with(List<int> runs) => ProfileStats(
  name: null,
  tag: null,
  games: [
    for (final (i, n) in runs.indexed)
      GameStat(game: GameId.values[i], best: 0, runs: n),
  ],
  runs: runs.fold(0, (a, b) => a + b),
  played: Duration.zero,
  playedIsPartial: false,
);

void main() {
  test('Sprint hint says how to unlock the score', () {
    expect(_with([0, 0]).sprintHint, 'Play 2 games, 3 times each, to get it');
    expect(_with([2, 2]).sprintHint, 'Play 2 games, 3 times each, to get it');
    expect(_with([3, 1]).sprintHint, 'Play 1 more game 3 times to get it');
    expect(_with([3, 5]).sprintHint, 'Updates daily · keep playing');
  });

  test('every game has a short tip for the Game Over card', () {
    for (final game in GameId.values) {
      expect(game.tip.length, lessThan(60), reason: game.name);
    }
  });
}
