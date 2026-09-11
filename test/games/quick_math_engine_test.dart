import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/quick_math/quick_math_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

int _solve(MathProblem p) => switch (p.op) {
  MathOp.add => p.a + p.b,
  MathOp.subtract => p.a - p.b,
  MathOp.multiply => p.a * p.b,
  MathOp.divide => p.a ~/ p.b,
};

int _wrong(MathProblem p) => p.options.firstWhere((o) => o != p.answer);

void main() {
  group('generate', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: valid problems at every level', () {
        final random = Random(7);
        for (var level = 0; level <= 6; level++) {
          for (var i = 0; i < 300; i++) {
            final p = QuickMathEngine.generate(difficulty, random, level);
            expect(QuickMathEngine.opsFor(difficulty, level), contains(p.op));
            expect(_solve(p), p.answer);
            if (p.op == MathOp.divide) {
              expect(p.a % p.b, 0);
            }
            expect(p.options.toSet(), hasLength(4));
            expect(p.options, contains(p.answer));
            expect(p.options.every((o) => o >= 0), isTrue);
          }
        }
      });
    }

    test('gets trickier as the level rises', () {
      expect(
        QuickMathEngine.opsFor(Difficulty.easy),
        isNot(contains(MathOp.multiply)),
      );
      expect(
        QuickMathEngine.opsFor(Difficulty.easy, 2),
        contains(MathOp.multiply),
      );
      expect(
        QuickMathEngine.opsFor(Difficulty.medium, 2),
        contains(MathOp.divide),
      );

      int largestAddend(int level) {
        final random = Random(1);
        var largest = 0;
        for (var i = 0; i < 400; i++) {
          final p = QuickMathEngine.generate(Difficulty.easy, random, level);
          if (p.op == MathOp.add) {
            largest = max(largest, max(p.a, p.b));
          }
        }
        return largest;
      }

      expect(largestAddend(4), greaterThan(largestAddend(0)));
    });
  });

  group('run', () {
    test('a correct answer scores, locks, then shows the next problem', () {
      fakeAsync((async) {
        final engine = QuickMathEngine(
          difficulty: Difficulty.easy,
          random: Random(1),
        )..start();
        final first = engine.problem;
        engine.answer(first.answer);
        expect(engine.score, 10);
        expect(engine.locked, isTrue);

        engine.answer(first.answer);
        expect(engine.correct, 1, reason: 'taps while locked are ignored');

        async.elapse(const Duration(milliseconds: 300));
        expect(engine.locked, isFalse);
        expect(engine.number, 2);
        engine.dispose();
      });
    });

    test('five correct in a row earn the streak bonus; levels every 10', () {
      fakeAsync((async) {
        final engine = QuickMathEngine(
          difficulty: Difficulty.medium,
          random: Random(2),
        )..start();
        for (var i = 0; i < 10; i++) {
          engine.answer(engine.problem.answer);
          async.elapse(const Duration(milliseconds: 300));
          if (i == 4) {
            expect(engine.score, 5 * 10 + 20);
          }
        }
        expect(engine.level, 1);
        expect(engine.state, RunState.playing, reason: 'no clock ends a run');
        engine.dispose();
      });
    });

    test('a wrong answer ends the run unless revived, once', () {
      fakeAsync((async) {
        final engine = QuickMathEngine(
          difficulty: Difficulty.easy,
          random: Random(3),
        )..start();
        engine.answer(engine.problem.answer);
        async.elapse(const Duration(seconds: 2));

        engine.answer(_wrong(engine.problem));
        expect(engine.state, RunState.down);
        expect(engine.canRevive, isTrue);
        engine.answer(engine.problem.answer);
        expect(engine.correct, 1, reason: 'no answers while down');

        async.elapse(const Duration(seconds: 5)); // watching the ad
        engine.revive();
        expect(engine.state, RunState.playing);
        expect(engine.number, 3, reason: 'a revive brings a fresh problem');

        async.elapse(const Duration(seconds: 1));
        engine.answer(_wrong(engine.problem));
        expect(engine.canRevive, isFalse);

        engine.finish();
        expect(engine.isFinished, isTrue);
        expect(engine.result!.score, 10);
        expect(
          engine.result!.duration,
          const Duration(seconds: 3),
          reason: 'time spent down is not counted',
        );
        engine.dispose();
      });
    });
  });
}
