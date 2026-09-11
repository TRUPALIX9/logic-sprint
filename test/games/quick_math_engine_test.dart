import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/quick_math/quick_math_engine.dart';
import 'package:logic_sprint/models/game.dart';

int _solve(MathProblem p) => switch (p.op) {
  MathOp.add => p.a + p.b,
  MathOp.subtract => p.a - p.b,
  MathOp.multiply => p.a * p.b,
  MathOp.divide => p.a ~/ p.b,
};

void main() {
  group('generate', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: valid problems and four distinct options', () {
        final random = Random(7);
        for (var i = 0; i < 500; i++) {
          final p = QuickMathEngine.generate(difficulty, random);
          expect(QuickMathEngine.opsFor(difficulty), contains(p.op));
          expect(_solve(p), p.answer);
          if (p.op == MathOp.divide) {
            expect(p.a % p.b, 0);
          }
          expect(p.answer, greaterThanOrEqualTo(0));
          expect(p.options.toSet(), hasLength(4));
          expect(p.options, contains(p.answer));
          expect(p.options.every((o) => o >= 0), isTrue);
        }
      });
    }
  });

  group('round', () {
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

    test('five correct in a row earn the streak bonus; a miss resets it', () {
      fakeAsync((async) {
        final engine = QuickMathEngine(
          difficulty: Difficulty.medium,
          random: Random(2),
        )..start();
        void answer({required bool right}) {
          final p = engine.problem;
          engine.answer(
            right ? p.answer : p.options.firstWhere((o) => o != p.answer),
          );
          async.elapse(const Duration(milliseconds: 300));
        }

        for (var i = 0; i < 5; i++) {
          answer(right: true);
        }
        expect(engine.score, 5 * 10 + 20);

        answer(right: false);
        expect(engine.wrong, 1);
        expect(engine.score, 70);
        engine.dispose();
      });
    });

    test('the round ends after 30 seconds with a result', () {
      fakeAsync((async) {
        final engine = QuickMathEngine(
          difficulty: Difficulty.hard,
          previousBest: 5,
          random: Random(3),
        )..start();
        engine.answer(engine.problem.answer);
        async.elapse(const Duration(seconds: 30));
        expect(engine.isFinished, isTrue);
        expect(engine.result!.score, 10);
        expect(engine.result!.isNewBest, isTrue);

        engine.answer(engine.problem.answer);
        expect(engine.result!.correct, 1, reason: 'no scoring after the end');
        engine.dispose();
      });
    });
  });
}
