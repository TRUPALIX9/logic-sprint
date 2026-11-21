import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/sprint_rating.dart';

List<({String player, int score, int tieKey})> _board(int players) => [
  for (var i = 0; i < players; i++)
    (player: 'p$i', score: (players - i) * 10, tieKey: i),
];

void main() {
  group('board percentile', () {
    test('mid-rank for ties: a shared top score is never 100', () {
      expect(SprintRating.percentile(better: 0, tied: 2, players: 40), 97.5);
      expect(SprintRating.percentile(better: 0, tied: 1, players: 40), 98.75);
      expect(SprintRating.percentile(better: 39, tied: 1, players: 40), 1.25);
    });

    test('boards under 30 players count for nothing', () {
      expect(
        SprintRating.board(GameId.quickMath, Difficulty.hard, _board(29)),
        isEmpty,
      );
      expect(
        SprintRating.board(GameId.quickMath, Difficulty.hard, _board(30)),
        hasLength(30),
      );
    });

    test(
      'Easy caps at 90, Medium at 97, Hard and games without levels at 100',
      () {
        double best(GameId g, Difficulty d) =>
            SprintRating.board(g, d, _board(100))['p0']!;
        expect(best(GameId.quickMath, Difficulty.easy), 90);
        expect(best(GameId.memoryLane, Difficulty.medium), 97);
        expect(best(GameId.angleSense, Difficulty.hard), 99.5);
        expect(best(GameId.rocketLaunch, Difficulty.medium), 99.5);
      },
    );

    test('scores of 0 are ignored: no board place, not in the count', () {
      final rows = [
        ..._board(30),
        for (var i = 0; i < 70; i++) (player: 'z$i', score: 0, tieKey: 0),
      ];
      final p = SprintRating.board(GameId.rocketLaunch, Difficulty.hard, rows);
      expect(p, hasLength(30));
      expect(p.keys.any((k) => k.startsWith('z')), isFalse);
      // The lowest real score is near the bottom, not lifted by the zeros.
      expect(p['p29'], closeTo(100 / 60, 0.01));
      expect(
        SprintRating.board(GameId.rocketLaunch, Difficulty.hard, [
          ..._board(29),
          (player: 'z', score: 0, tieKey: 0),
        ]),
        isEmpty,
      );
    });

    test('equal scores get their own places (earlier best wins)', () {
      final rows = [
        for (var i = 0; i < 40; i++)
          (player: 'p$i', score: 50, tieKey: 1700000000000 + i),
      ];
      final p = SprintRating.board(GameId.guessColor, Difficulty.hard, rows);
      expect(p.values.toSet(), hasLength(40), reason: 'no shared rank');
      expect(p['p0']! > p['p39']!, isTrue);
    });

    test('a faster run wins a tie, like the boards', () {
      final rows = [
        for (var i = 0; i < 30; i++)
          (player: 'p$i', score: 100, tieKey: 1000 + i),
      ];
      final p = SprintRating.board(GameId.quickMath, Difficulty.hard, rows);
      expect(p['p0']! > p['p1']!, isTrue);
    });
  });

  group('combine', () {
    test('one game at 99 is 66 (as the plan says); four at 90 are 76.7', () {
      expect(SprintRating.combine([99]), closeTo(66.33, 0.01));
      expect(SprintRating.combine([90, 90, 90, 90]), closeTo(76.67, 0.01));
    });

    test('steady skill beats one spike', () {
      expect(
        SprintRating.combine([80, 80, 80]) > SprintRating.combine([99, 40]),
        isTrue,
      );
    });
  });

  group('rating and top', () {
    test('rating is the percentile of R among rated players', () {
      final r = SprintRating.ratings({'a': 80, 'b': 70, 'c': 70, 'd': 60});
      expect(r['a'], 87.5);
      expect(r['b'], 50);
      expect(r['d'], 12.5);
    });

    test(
      'top rounds up to 1, 2, 5, 10, 15, 20, 25, then tens, and never overclaims',
      () {
        expect(SprintRating.top(100), 1);
        expect(SprintRating.top(99.4), 1);
        expect(SprintRating.top(98.5), 2);
        expect(SprintRating.top(97.9), 5);
        expect(SprintRating.top(91), 10);
        expect(SprintRating.top(80), 20);
        expect(SprintRating.top(76), 25);
        expect(SprintRating.top(60.2), 40);
        expect(SprintRating.top(36.5), 70);
        expect(SprintRating.top(0), 100);
      },
    );
  });
}
