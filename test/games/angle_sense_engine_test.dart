import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/angle_sense/angle_sense_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

class _Feedback implements RoundFeedback {
  int corrects = 0;
  int wrongs = 0;

  @override
  void tap() {}

  @override
  void correct() => corrects++;

  @override
  void wrong() => wrongs++;
}

typedef E = AngleSenseEngine;

void main() {
  // Reveal for the tier + the hit or miss pause.
  const hitWait = Duration(milliseconds: 1350); // normal 700 + 650
  const perfectWait = Duration(milliseconds: 1550); // perfect 900 + 650
  const closeWait = Duration(milliseconds: 2650); // close 1600 + 400 + 650
  const missWait = Duration(milliseconds: 1800); // normal 700 + 1100
  const nearMissWait = Duration(milliseconds: 3100); // close 2000 + 1100

  E engine(Difficulty difficulty, {int seed = 1, _Feedback? feedback}) =>
      E(difficulty: difficulty, random: Random(seed), feedback: feedback);

  /// Sets the answer [off] degrees from the truth (READ tape or DRAW aim).
  void answer(E e, [int off = 0]) {
    final truth = e.question.answer;
    if (e.rule == AngleRule.read) {
      e.setGuess(truth + off);
    } else {
      e.aim((truth + off).toDouble());
    }
  }

  /// An answer far outside any window.
  void answerWrong(E e) {
    final truth = e.question.answer;
    answer(e, truth >= 180 ? -90 : 90);
  }

  /// Locks right answers until question [n] is showing.
  void advanceTo(E e, FakeAsync async, int n) {
    while (e.number < n) {
      answer(e);
      e.lock();
      expect(e.outcome!.grade.isHit, isTrue);
      async.elapse(perfectWait);
    }
  }

  /// Questions [from]..[to], chaining the rule like the engine does.
  List<AngleQuestion> run(Difficulty d, int from, int to, Random random) {
    var rule = AngleRule.read;
    var ruleRun = E.minRuleRun;
    final questions = <AngleQuestion>[];
    for (var n = from; n <= to; n++) {
      final q = E.generate(n, d, random, previousRule: rule, ruleRun: ruleRun);
      if (q.kind != AngleKind.compassRound) {
        ruleRun = q.rule == rule ? ruleRun + 1 : 1;
        rule = q.rule;
      }
      questions.add(q);
    }
    return questions;
  }

  group('angle error', () {
    test('wraps around: 359° vs 1° is 2°', () {
      expect(E.angleError(359, 1), 2);
      expect(E.angleError(1, 359), 2);
      expect(E.signedError(359, 1), -2);
      expect(E.signedError(1, 359), 2);
      expect(E.angleError(0, 360), 0);
      expect(E.angleError(10, 190), 180);
      expect(E.signedError(95, 90), 5);
    });

    test('a DRAW answer across 0° scores by the short way round', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        e.question = const AngleQuestion(
          kind: AngleKind.drawRotated,
          answer: 2,
          vertex: Offset(0.5, 0.5),
          base: 0,
        );
        e.aim(-1);
        expect(e.drawGuess, 359);
        e.lock();
        expect(e.outcome!.error, -3);
        expect(e.outcome!.grade, AngleGrade.sharp);
        e.dispose();
      });
    });
  });

  group('opening', () {
    const openings = {
      Difficulty.easy: (flat: 7, vertical: 14, crossed: 25),
      Difficulty.medium: (flat: 3, vertical: 6, crossed: 9),
      Difficulty.hard: (flat: 2, vertical: 4, crossed: 6),
    };
    for (final MapEntry(key: d, value: ends) in openings.entries) {
      test('${d.name}: flat → vertical → crossed', () {
        for (var seed = 0; seed < 30; seed++) {
          final random = Random(seed);
          for (var n = 1; n <= ends.crossed; n++) {
            final q = E.generate(n, d, random);
            final kind = n <= ends.flat
                ? AngleKind.flat
                : n <= ends.vertical
                ? AngleKind.vertical
                : AngleKind.crossed;
            expect(q.kind, kind, reason: '${d.name} Q$n');
            expect(q.rule, AngleRule.read);
            switch (kind) {
              case AngleKind.flat:
                expect(q.base, 0);
                expect(q.dir, 1);
                expect(
                  (q.vertex - const Offset(0.5, 0.5)).distance,
                  lessThan(0.2),
                );
              case AngleKind.vertical:
                expect(q.base, 90);
              default:
                // One of the two lines is flat or vertical.
                final lines = [q.base, q.armAt(q.answer)];
                expect(lines.any((a) => E.norm(a) % 90 == 0), isTrue);
            }
            // Every arm stays on the card.
            for (final arm in [q.base, q.armAt(q.answer)]) {
              final tip = q.point(arm, q.armLength);
              expect(tip.dx, inInclusiveRange(0.05, 0.95));
              expect(tip.dy, inInclusiveRange(0.05, 0.95));
            }
          }
        }
      });
    }

    test('crossed: the marked angle is one of the four', () {
      for (var seed = 0; seed < 100; seed++) {
        final q = E.generate(15, Difficulty.easy, Random(seed));
        expect(q.answer, inInclusiveRange(20, 160));
      }
    });
  });

  group('ladder', () {
    test('window per stage', () {
      const windows = {
        Difficulty.easy: {1: 8, 7: 8, 8: 7, 14: 7, 15: 6, 40: 6, 41: 5, 99: 5},
        Difficulty.medium: {
          1: 8,
          6: 8,
          7: 7,
          13: 7,
          20: 12,
          21: 6,
          39: 6,
          41: 5,
        },
        Difficulty.hard: {1: 9, 6: 9, 7: 8, 20: 8, 21: 7, 50: 7, 51: 6},
      };
      windows.forEach((d, table) {
        table.forEach((n, window) {
          expect(E.windowFor(d, n), window, reason: '${d.name} Q$n');
        });
      });
    });

    test('timer per stage', () {
      Duration ms(int ms) => Duration(milliseconds: ms);
      final timers = {
        Difficulty.easy: {1: null, 40: null, 200: null},
        Difficulty.medium: {
          1: null,
          12: null,
          13: ms(8000),
          21: ms(7000),
          31: ms(6000),
          41: ms(5500),
          50: null,
        },
        Difficulty.hard: {
          1: ms(6000),
          6: ms(6000),
          7: ms(5500),
          13: ms(5000),
          21: ms(4500),
          31: ms(4000),
          51: ms(4000),
        },
      };
      timers.forEach((d, table) {
        table.forEach((n, limit) {
          expect(E.timeLimitFor(d, n), limit, reason: '${d.name} Q$n');
        });
      });
    });

    test('scenes per stage', () {
      Set<AngleKind> kinds(Difficulty d, int from, int to) => {
        for (var seed = 0; seed < 40; seed++)
          for (final q in run(d, from, to, Random(seed))) q.kind,
      };
      expect(kinds(Difficulty.medium, 11, 12), {
        AngleKind.clock,
        AngleKind.pie,
        AngleKind.bearing,
      });
      expect(kinds(Difficulty.medium, 21, 29), contains(AngleKind.drawClock));
      expect(kinds(Difficulty.easy, 26, 40), contains(AngleKind.drawFlat));
      expect(kinds(Difficulty.hard, 7, 12), {
        AngleKind.rays,
        AngleKind.crossed,
        AngleKind.pie,
        AngleKind.triangle,
      });
      expect(kinds(Difficulty.hard, 13, 20), contains(AngleKind.drawRotated));
    });

    test('reflex angles only from Hard 21', () {
      int biggest(int from, int to) => [
        for (var seed = 0; seed < 40; seed++)
          for (final q in run(Difficulty.hard, from, to, Random(seed)))
            if (q.rule == AngleRule.read) q.answer,
      ].reduce(max);
      expect(biggest(7, 20), lessThanOrEqualTo(180));
      expect(biggest(21, 30), greaterThan(190));
    });

    test('tricks only from Hard 31', () {
      bool tricky(AngleQuestion q) =>
          q.dashed || q.decoy || q.secondArmLength != q.armLength;
      List<AngleQuestion> rays(int from, int to) => [
        for (var seed = 0; seed < 40; seed++)
          for (final q in run(Difficulty.hard, from, to, Random(seed)))
            if (q.kind == AngleKind.rays) q,
      ];
      expect(rays(7, 30).where(tricky), isEmpty);
      expect(rays(31, 50).where(tricky), isNotEmpty);
    });
  });

  group('READ / DRAW rule', () {
    test('no DRAW before the stages that allow it', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        for (final (d, last) in [
          (Difficulty.easy, 25),
          (Difficulty.medium, 19),
          (Difficulty.hard, 12),
        ]) {
          expect(
            run(d, 1, last, random).where(
              (q) =>
                  q.rule == AngleRule.draw && q.kind != AngleKind.compassRound,
            ),
            isEmpty,
          );
        }
      }
    });

    test('each rule holds at least 2 questions; about 35% DRAW', () {
      var draws = 0, total = 0;
      for (var seed = 0; seed < 40; seed++) {
        final questions = run(Difficulty.hard, 13, 200, Random(seed));
        final rules = [for (final q in questions) q.rule];
        total += rules.length;
        draws += rules.where((r) => r == AngleRule.draw).length;
        // Q1–12 were all READ, so the first run is already long enough.
        var length = E.minRuleRun;
        for (var i = 1; i < rules.length; i++) {
          if (rules[i] == rules[i - 1]) {
            length++;
          } else {
            expect(length, greaterThanOrEqualTo(E.minRuleRun));
            length = 1;
          }
        }
      }
      expect(draws / total, inInclusiveRange(0.25, 0.45));
    });

    test('the engine keeps rule runs of at least 2', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard, seed: 3)..start();
        advanceTo(e, async, 13);
        final rules = <AngleRule>[e.rule];
        while (e.number < 90) {
          advanceTo(e, async, e.number + 1);
          rules.add(e.rule);
        }
        var length = 1;
        for (var i = 1; i < rules.length; i++) {
          if (rules[i] == rules[i - 1]) {
            length++;
          } else {
            expect(length, greaterThanOrEqualTo(2));
            length = 1;
          }
        }
        expect(rules, contains(AngleRule.draw));
        e.finish();
        e.dispose();
      });
    });

    test('DRAW needs an aim before Lock', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        e.question = E.generate(
          20,
          Difficulty.hard,
          Random(1),
          previousRule: AngleRule.draw,
          ruleRun: 1,
        );
        expect(e.rule, AngleRule.draw);
        expect(e.canLock, isFalse);
        e.lock();
        expect(e.outcome, isNull);
        e.aim(e.question.answer.toDouble());
        expect(e.canLock, isTrue);
        e.finish();
        e.dispose();
      });
    });
  });

  group('compass round', () {
    test('Medium every 10th question: compass, ±12°, no timer', () {
      for (final n in [10, 20, 30, 40, 50, 100]) {
        final q = E.generate(n, Difficulty.medium, Random(n));
        expect(q.kind, AngleKind.compassRound, reason: 'Q$n');
        expect(q.rule, AngleRule.draw);
        expect(q.heading, startsWith('FACE '));
        expect(E.windowFor(Difficulty.medium, n), 12);
        expect(E.timeLimitFor(Difficulty.medium, n), isNull);
      }
      for (final n in [9, 11, 19, 21]) {
        expect(
          E.generate(n, Difficulty.medium, Random(n)).kind,
          isNot(AngleKind.compassRound),
        );
      }
      for (final d in [Difficulty.easy, Difficulty.hard]) {
        expect(
          E.generate(10, d, Random(1)).kind,
          isNot(AngleKind.compassRound),
        );
      }
    });

    test('the heading names the nearest point', () {
      const q = AngleQuestion(
        kind: AngleKind.compassRound,
        answer: 135,
        vertex: Offset(0.5, 0.5),
        base: 90,
        dir: -1,
      );
      expect(q.heading, 'FACE SE · 135°');
    });

    test('a Medium run reaches one on question 10 and 20', () {
      fakeAsync((async) {
        final e = engine(Difficulty.medium)..start();
        advanceTo(e, async, 10);
        expect(e.isCompassRound, isTrue);
        expect(e.window, 12);
        expect(e.timeLeft, isNull);
        advanceTo(e, async, 20);
        expect(e.isCompassRound, isTrue);
        expect(e.timeLeft, isNull);
        advanceTo(e, async, 21);
        expect(e.isCompassRound, isFalse);
        expect(e.timeLeft, const Duration(seconds: 7));
        e.finish();
        e.dispose();
      });
    });
  });

  group('scoring', () {
    test('Bullseye +10, Sharp +5, Hit +0 on top of 10', () {
      fakeAsync((async) {
        final feedback = _Feedback();
        final e = engine(Difficulty.easy, feedback: feedback)..start();
        answer(e);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.bullseye);
        expect(e.outcome!.label, 'BULLSEYE 0°');
        expect(e.score, 20);
        async.elapse(perfectWait);

        answer(e, -1);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.bullseye);
        expect(e.outcome!.label, 'BULLSEYE −1°');
        expect(e.score, 40);
        async.elapse(perfectWait);

        answer(e, 2);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.sharp);
        expect(e.outcome!.label, 'SHARP +2°');
        expect(e.score, 55);
        async.elapse(closeWait);

        answer(e, -6);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.hit);
        expect(e.outcome!.label, 'HIT −6°');
        expect(e.score, 65);
        expect(e.correct, 4);
        expect(feedback.corrects, 4);
        e.finish();
        e.dispose();
      });
    });

    test('the window is inclusive: ±8 hits, ±9 misses on Easy Q1', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        answer(e, 8);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.hit);
        async.elapse(hitWait);
        answer(e, -9);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.miss);
        expect(e.outcome!.label, 'MISS −9°');
        e.finish();
        e.dispose();
      });
    });

    test('the next question waits for the reveal', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        answer(e);
        e.lock();
        async.elapse(perfectWait - const Duration(milliseconds: 1));
        expect(e.number, 1);
        expect(e.locked, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.number, 2);
        expect(e.outcome, isNull);
        e.finish();
        e.dispose();
      });
    });
  });

  group('reveal tier', () {
    test('bullseye is perfect, sharp is close, hit is normal', () {
      expect(E.tierFor(AngleGrade.bullseye, 0, 8), RevealTier.perfect);
      expect(E.tierFor(AngleGrade.bullseye, -1, 8), RevealTier.perfect);
      expect(E.tierFor(AngleGrade.sharp, 2, 8), RevealTier.close);
      expect(E.tierFor(AngleGrade.sharp, -3, 8), RevealTier.close);
      expect(E.tierFor(AngleGrade.hit, 6, 8), RevealTier.normal);
      expect(E.tierFor(AngleGrade.time, null, 8), RevealTier.normal);
    });

    test('a miss within window + 3 is close, past it is normal', () {
      expect(E.tierFor(AngleGrade.miss, 9, 8), RevealTier.close);
      expect(E.tierFor(AngleGrade.miss, -11, 8), RevealTier.close);
      expect(E.tierFor(AngleGrade.miss, 12, 8), RevealTier.normal);
      expect(E.tierFor(AngleGrade.miss, 90, 8), RevealTier.normal);
    });

    test('reveal lengths per tier', () {
      expect(
        E.revealFor(RevealTier.perfect),
        const Duration(milliseconds: 900),
      );
      expect(E.revealFor(RevealTier.close), const Duration(milliseconds: 2000));
      expect(E.sweepFor(RevealTier.close), const Duration(milliseconds: 1600));
      expect(E.revealFor(RevealTier.normal), const Duration(milliseconds: 700));
    });

    test('the outcome carries the tier and the chip text', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        answer(e, 1);
        e.lock();
        expect(e.outcome!.tier, RevealTier.perfect);
        expect(e.outcome!.chip, 'PERFECT +1°');
        async.elapse(perfectWait);
        answer(e, -2);
        e.lock();
        expect(e.outcome!.tier, RevealTier.close);
        expect(e.outcome!.chip, 'SHARP −2°');
        async.elapse(closeWait);
        answer(e, 10);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.miss);
        expect(e.outcome!.nearMiss, isTrue);
        expect(e.outcome!.chip, 'SO CLOSE +10°');
        expect(e.outcome!.label, 'MISS +10°');
        e.finish();
        e.dispose();
      });
    });

    /// Locks [off] from the truth on Easy Q1 (window ±8) and checks the
    /// next question comes exactly after [wait].
    void nextAfter(int off, Duration wait) {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        answer(e, off);
        e.lock();
        async.elapse(wait - const Duration(milliseconds: 1));
        expect(e.number, 1, reason: 'still revealing');
        async.elapse(const Duration(milliseconds: 1));
        expect(e.number, 2);
        e.finish();
        e.dispose();
      });
    }

    test('perfect: next question at 900 + 650 ms', () {
      nextAfter(0, perfectWait);
    });
    test('close (sharp): next question at 1600 + 400 + 650 ms', () {
      nextAfter(3, closeWait);
    });
    test('normal hit: next question at 700 + 650 ms', () {
      nextAfter(-5, hitWait);
    });
    test('near miss: next question at 1600 + 400 + 1100 ms', () {
      nextAfter(11, nearMissWait);
    });
    test('far miss: next question at 700 + 1100 ms', () {
      nextAfter(-12, missWait);
    });

    test('the last shield on a near miss goes down after the slow reveal', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        answerWrong(e);
        e.lock();
        async.elapse(missWait);
        answer(e, 9);
        e.lock();
        expect(e.outcome!.tier, RevealTier.close);
        async.elapse(nearMissWait - const Duration(milliseconds: 1));
        expect(e.state, RunState.playing);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.state, RunState.down);
        e.finish();
        e.dispose();
      });
    });

    test('pause holds the slow reveal', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        answer(e, 2);
        e.lock();
        async.elapse(const Duration(milliseconds: 1000));
        e.pause();
        async.elapse(const Duration(seconds: 10));
        expect(e.number, 1);
        e.resume();
        async.elapse(closeWait - const Duration(milliseconds: 1001));
        expect(e.number, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.number, 2);
        e.finish();
        e.dispose();
      });
    });
  });

  group('shields', () {
    test('a miss resets the streak bonus', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        advanceTo(e, async, 5);
        expect(e.score, 80);
        answerWrong(e);
        e.lock();
        async.elapse(missWait);
        answer(e);
        e.lock();
        // The 5th hit, but not 5 in a row: no streak bonus.
        expect(e.score, 100);
        e.finish();
        e.dispose();
      });
    });

    test('2 shields: 1 miss continues; the 2nd goes down after the reveal', () {
      fakeAsync((async) {
        final feedback = _Feedback();
        final e = engine(Difficulty.easy, feedback: feedback)..start();
        expect(E.maxStrikes, 2);
        expect(e.strikesLeft, 2);
        answerWrong(e);
        e.lock();
        expect(e.outcome!.grade, AngleGrade.miss);
        expect(e.strikesLeft, 1);
        expect(feedback.wrongs, 1);
        async.elapse(missWait);
        expect(e.state, RunState.playing);
        expect(e.number, 2);

        answerWrong(e);
        e.lock();
        expect(e.strikesLeft, 0);
        expect(e.state, RunState.playing); // the reveal plays first
        async.elapse(missWait - const Duration(milliseconds: 1));
        expect(e.state, RunState.playing);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.state, RunState.down);
        expect(feedback.wrongs, 2);
        expect(e.score, 0);
        e.finish();
        e.dispose();
      });
    });

    test('a timeout counts as a miss', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        async.elapse(const Duration(seconds: 6));
        expect(e.outcome!.grade, AngleGrade.time);
        expect(e.outcome!.label, 'TIME');
        expect(e.strikesLeft, 1);
        async.elapse(missWait);
        expect(e.number, 2);
        expect(e.state, RunState.playing);
        // One more timeout ends it.
        async.elapse(const Duration(seconds: 6) + missWait);
        expect(e.state, RunState.down);
        e.finish();
        e.dispose();
      });
    });

    test('a timeout scores a miss even if the tape was right', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        answer(e);
        async.elapse(const Duration(seconds: 6));
        expect(e.outcome!.grade, AngleGrade.time);
        expect(e.score, 0);
        e.finish();
        e.dispose();
      });
    });
  });

  group('timer', () {
    test('pause keeps the remaining time', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        async.elapse(const Duration(seconds: 2));
        e.pause();
        async.elapse(const Duration(seconds: 30));
        expect(e.outcome, isNull);
        expect(e.timeLeft, const Duration(seconds: 4));
        e.resume();
        async.elapse(const Duration(milliseconds: 3999));
        expect(e.outcome, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.outcome!.grade, AngleGrade.time);
        e.finish();
        e.dispose();
      });
    });

    test('pause holds the next-question delay too', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        answer(e);
        e.lock();
        async.elapse(const Duration(milliseconds: 1000));
        e.pause();
        async.elapse(const Duration(seconds: 10));
        expect(e.number, 1);
        e.resume();
        async.elapse(const Duration(milliseconds: 550));
        expect(e.number, 2);
        expect(e.timeLeft, const Duration(seconds: 6));
        e.finish();
        e.dispose();
      });
    });
  });

  group('revive', () {
    void strikeOut(E e, FakeAsync async) {
      for (var i = 0; i < E.maxStrikes; i++) {
        answerWrong(e);
        e.lock();
        async.elapse(missWait);
      }
      expect(e.state, RunState.down);
    }

    test('hold: one shield left, timers held until go()', () {
      fakeAsync((async) {
        final e = engine(Difficulty.hard)..start();
        strikeOut(e, async);
        final number = e.number;
        final before = e.question;
        e.revive(hold: true);
        expect(e.state, RunState.resuming);
        expect(e.strikesLeft, 1);
        expect(e.number, number);
        expect(e.question, isNot(same(before)));
        expect(e.outcome, isNull);
        expect(E.stageFor(Difficulty.hard, e.number).window, e.window);

        async.elapse(const Duration(seconds: 20));
        expect(e.outcome, isNull);
        expect(e.timeLeft, const Duration(seconds: 6));

        e.go();
        expect(e.state, RunState.playing);
        answer(e);
        e.lock();
        expect(e.outcome!.grade.isHit, isTrue);
        async.elapse(perfectWait);
        expect(e.number, number + 1);
        expect(e.strikesLeft, 1);

        // The one strike left: the next miss goes down again.
        async.elapse(const Duration(seconds: 6) + missWait);
        expect(e.state, RunState.down);
        e.finish();
        e.dispose();
      });
    });

    test('without hold it plays on at once', () {
      fakeAsync((async) {
        final e = engine(Difficulty.easy)..start();
        strikeOut(e, async);
        e.revive();
        expect(e.state, RunState.playing);
        expect(e.strikesLeft, 1);
        expect(e.number, 2);
        // One shield back, not two: the next miss goes down.
        answerWrong(e);
        e.lock();
        async.elapse(missWait);
        expect(e.state, RunState.down);
        e.finish();
        e.dispose();
      });
    });
  });
}
