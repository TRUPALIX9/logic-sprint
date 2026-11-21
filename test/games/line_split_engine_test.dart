import 'dart:math';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/line_split/line_split_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

class _Feedback implements RoundFeedback {
  int taps = 0;
  int rights = 0;
  int wrongs = 0;

  @override
  void tap() => taps++;
  @override
  void correct() => rights++;
  @override
  void wrong() => wrongs++;
}

void main() {
  const fractions = [
    1 / 2, 1 / 3, 2 / 3, 1 / 4, 3 / 4, //
    1 / 5, 2 / 5, 3 / 5, 4 / 5, 1 / 8, 3 / 8, 5 / 8, 7 / 8,
  ];

  /// An engine at question [number] (built inside fakeAsync for its clock).
  LineSplitEngine engineAt(
    int number, {
    int seed = 1,
    RoundFeedback? feedback,
  }) {
    final e = LineSplitEngine(
      difficulty: Difficulty.medium,
      random: Random(seed),
      feedback: feedback,
    );
    e
      ..number = number
      ..question = LineSplitEngine.generate(number, Random(seed));
    return e;
  }

  /// Questions [from]..[to] chained like the engine does, across seeds.
  List<SplitQuestion> questions(int from, int to, {int seeds = 30}) {
    final all = <SplitQuestion>[];
    for (var seed = 0; seed < seeds; seed++) {
      final random = Random(seed);
      SplitTarget? previous;
      for (var n = from; n <= to; n++) {
        final q = LineSplitEngine.generate(n, random, previous: previous);
        previous = q.target;
        all.add(q);
      }
    }
    return all;
  }

  Set<(int?, int?)> fractionsOf(List<SplitQuestion> qs) => {
    for (final q in qs) (q.target.numerator, q.target.denominator),
  };

  /// An answer [share] of the line away from the target.
  double missBy(LineSplitEngine e, double share) {
    final up = e.target.position + share;
    return up <= 1 ? up : e.target.position - share;
  }

  group('stages', () {
    test('ramp by question number', () {
      const expected = {
        1: SplitStage.halves,
        6: SplitStage.halves,
        7: SplitStage.upright,
        12: SplitStage.upright,
        13: SplitStage.crossed,
        20: SplitStage.crossed,
        21: SplitStage.finer,
        30: SplitStage.finer,
        31: SplitStage.decimals,
        40: SplitStage.decimals,
        41: SplitStage.tricks,
        50: SplitStage.tricks,
        51: SplitStage.everything,
        400: SplitStage.everything,
      };
      expected.forEach((n, stage) {
        expect(SplitStage.of(n), stage, reason: 'question $n');
      });
    });

    test('window and timer per stage', () {
      const expected = {
        1: (5.0, null),
        7: (5.0, null),
        13: (5.5, null),
        21: (5.5, null),
        31: (6.0, Duration(seconds: 5)),
        41: (6.0, Duration(seconds: 4)),
        51: (5.5, Duration(milliseconds: 3500)),
      };
      expected.forEach((n, want) {
        final stage = SplitStage.of(n);
        expect(stage.window, want.$1, reason: 'question $n');
        expect(stage.timeLimit, want.$2, reason: 'question $n');
      });
    });

    test('1–6: flat long lines; ½ then ⅓, then thirds and quarters', () {
      for (final q in questions(1, 6)) {
        expect(q.line.degrees, 0);
        expect(q.line.length, inInclusiveRange(0.8, 0.92));
        expect(q.decoy, isNull);
        expect(q.ticks, isEmpty);
      }
      expect(fractionsOf(questions(1, 1, seeds: 20)), {(1, 2)});
      expect(fractionsOf(questions(2, 2, seeds: 20)), {(1, 3)});
      expect(fractionsOf(questions(3, 6)), {(2, 3), (1, 4), (3, 4)});
    });

    test('½ and ⅓ are asked once at the start, never again', () {
      for (final q in questions(3, 90, seeds: 40)) {
        final f = (q.target.numerator, q.target.denominator);
        if (q.target.kind == TargetKind.fraction && !q.target.isMultiUnit) {
          expect(LineSplitEngine.easyOpeners, isNot(contains(f)));
        }
      }
    });

    test('7–12: upright lines, thirds quarters fifths', () {
      final qs = questions(7, 12);
      for (final q in qs) {
        expect(q.line.degrees, 90);
        expect(q.decoy, isNull);
      }
      expect(fractionsOf(qs), {(2, 3), (1, 4), (3, 4), (1, 5), (4, 5)});
    });

    test('13–20: diagonal lines crossed by a decoy', () {
      // From Q17 some lines are longer number lines; those are tested apart.
      final qs = questions(13, 20).where((q) => !q.target.isMultiUnit).toList();
      for (final q in qs) {
        expect([30, -30, 60, -60], contains(q.line.degrees));
        final decoy = q.decoy!;
        expect(decoy.degrees, -q.line.degrees);
        // The decoy fits the frame: no end past half the shortest side.
        expect(
          decoy.shift.distance + decoy.length / 2,
          lessThanOrEqualTo(0.5 + 1e-9),
        );
        expect(q.target.kind, TargetKind.fraction);
      }
      expect(fractionsOf(qs), {
        (2, 3), (1, 4), (3, 4), //
        (1, 8), (3, 8), (5, 8), (7, 8),
      });
    });

    test('21–30: any direction, eighths and fifths', () {
      final qs = questions(21, 30).where((q) => q.target.units == 1).toList();
      for (final q in qs) {
        expect(q.line.length, inInclusiveRange(0.6, 0.92));
        expect(q.decoy, isNull);
      }
      expect(qs.map((q) => q.line.degrees).toSet(), containsAll([0, 90, 30]));
      expect(fractionsOf(qs), {
        (1, 8), (3, 8), (5, 8), (7, 8), //
        (1, 5), (2, 5), (3, 5), (4, 5),
      });
    });

    test('31–40: decimals and percents that avoid simple fractions', () {
      final qs = questions(31, 40).where((q) => q.target.units == 1).toList();
      final kinds = {for (final q in qs) q.target.kind};
      expect(kinds, {TargetKind.decimal, TargetKind.percent});
      for (final q in qs) {
        final v = q.target.shown;
        expect(v, inInclusiveRange(0.06, 0.94));
        expect((v * 100).roundToDouble(), closeTo(v * 100, 1e-9));
        for (final f in fractions) {
          expect((v - f).abs(), greaterThanOrEqualTo(0.025 - 1e-9));
        }
        expect(q.target.fromOne, isFalse);
      }
    });

    test('decimal() avoids simple fractions across many draws', () {
      final random = Random(5);
      for (var i = 0; i < 2000; i++) {
        final v = LineSplitEngine.decimal(random);
        for (final f in fractions) {
          expect((v - f).abs(), greaterThanOrEqualTo(0.025 - 1e-9));
        }
      }
    });

    test('41–50: tricks, from the 1 end or fake ticks', () {
      final qs = questions(41, 50).where((q) => q.target.units == 1).toList();
      expect(qs.any((q) => q.target.fromOne), isTrue);
      expect(qs.any((q) => q.target.ticks), isTrue);
      for (final q in qs) {
        expect(q.target.fromOne || q.target.ticks, isTrue);
        if (q.target.ticks) {
          expect(q.ticks.length, inInclusiveRange(3, 4));
          expect(q.target.subtitle, 'ignore the ticks');
          // Near an even spacing but never on it.
          final count = q.ticks.length;
          for (var k = 0; k < count; k++) {
            final tick = q.ticks[k];
            expect((tick - q.target.position).abs(), greaterThan(0.02));
            expect(
              (tick - (k + 1) / (count + 1)).abs(),
              inInclusiveRange(0.03 - 1e-9, 0.07 + 1e-9),
            );
          }
        } else {
          expect(q.ticks, isEmpty);
          expect(q.target.subtitle, 'from the 1 end');
        }
      }
    });

    test('51+: everything', () {
      final qs = questions(51, 70);
      expect(qs.map((q) => q.target.kind).toSet(), TargetKind.values.toSet());
      expect(qs.any((q) => q.target.fromOne), isTrue);
      expect(qs.any((q) => q.target.ticks), isTrue);
      expect(qs.any((q) => q.decoy != null), isTrue);
    });

    test('never the same target twice in a row (past the halves)', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        SplitTarget? previous;
        for (var n = 7; n <= 90; n++) {
          final q = LineSplitEngine.generate(n, random, previous: previous);
          if (previous != null) {
            expect(q.target.sameAs(previous), isFalse, reason: 'q$n s$seed');
          }
          previous = q.target;
        }
      }
    });
  });

  group('targets', () {
    test('labels and subtitles', () {
      const half = SplitTarget.fraction(3, 8);
      expect(half.text, isNull);
      expect(half.subtitle, 'from the 0 end');
      expect(const SplitTarget.decimal(0.43).text, '0.43');
      expect(const SplitTarget.percent(0.37).text, '37%');
    });

    test('"from the 1 end" counts from the other end', () {
      const target = SplitTarget.decimal(0.30, fromOne: true);
      expect(target.position, closeTo(0.70, 1e-12));
      expect(target.text, '0.30');
      expect(target.subtitle, 'from the 1 end');

      fakeAsync((async) {
        final e = engineAt(41)
          ..question = const SplitQuestion(
            target: target,
            line: SplitLine(degrees: 0, length: 0.9),
          )
          ..start();
        // 0.68 from the 0 end is 0.32 from the 1 end: 2% past the target.
        e.answer(0.68);
        expect(e.outcome!.verdict, SplitVerdict.sharp);
        expect(e.outcome!.signedError, closeTo(2, 1e-9));
        expect(e.outcome!.label, 'SHARP +2.0%');
        e.dispose();
      });
    });
  });

  group('geometry', () {
    const frame = Rect.fromLTWH(10, 20, 200, 320);

    test('flat line: 0 at the left; upright: 0 at the bottom', () {
      const flat = SplitLine(degrees: 0, length: 0.8);
      expect(flat.start(frame).dx, lessThan(flat.end(frame).dx));
      expect(flat.start(frame).dy, closeTo(flat.end(frame).dy, 1e-9));
      expect(
        (flat.end(frame) - flat.start(frame)).distance,
        closeTo(160, 1e-9),
      );

      const upright = SplitLine(degrees: 90, length: 0.8);
      expect(upright.start(frame).dy, greaterThan(upright.end(frame).dy));
      expect(upright.start(frame).dx, closeTo(upright.end(frame).dx, 1e-9));
    });

    test('projection onto rotated lines', () {
      for (final degrees in <double>[0, 90, 30, -30, 60, -60, 45, 15]) {
        final line = SplitLine(
          degrees: degrees,
          length: 0.7,
          shift: const Offset(0.05, -0.03),
        );
        final dir = line.direction;
        final normal = Offset(-dir.dy, dir.dx);
        for (final u in [0.0, 0.125, 0.37, 0.5, 0.81, 1.0]) {
          // A finger off to either side of the line still maps to u.
          for (final side in <double>[-30, 0, 18]) {
            final p = line.at(frame, u) + normal * side;
            expect(line.project(frame, p), closeTo(u, 1e-9));
          }
        }
        // Past the ends clamps to 0 and 1.
        expect(line.project(frame, line.start(frame) - dir * 40), 0);
        expect(line.project(frame, line.end(frame) + dir * 40), 1);
      }
    });

    test('error is a share of the line, whatever its length or angle', () {
      fakeAsync((async) {
        for (final line in const [
          SplitLine(degrees: 0, length: 0.92),
          SplitLine(degrees: -60, length: 0.6),
        ]) {
          final e = engineAt(21)
            ..question = SplitQuestion(
              target: const SplitTarget.fraction(3, 8),
              line: line,
            )
            ..start();
          final dir = line.direction;
          // 4% of this line past 3/8, plus a sideways wobble.
          final length = line.length * frame.shortestSide;
          final p =
              line.at(frame, 3 / 8) +
              dir * (0.04 * length) +
              Offset(-dir.dy, dir.dx) * 12;
          e.answer(line.project(frame, p));
          expect(e.outcome!.error, closeTo(4, 1e-6));
          expect(e.outcome!.verdict, SplitVerdict.hit);
          e.dispose();
        }
      });
    });
  });

  group('shields', () {
    test('two shields: one miss goes on, the second goes down', () {
      fakeAsync((async) {
        final feedback = _Feedback();
        final e = engineAt(7, feedback: feedback)..start();
        expect(LineSplitEngine.maxStrikes, 2);
        expect(e.strikesLeft, 2);

        // 9% off a ±5% window: a far miss, the plain reveal.
        e.answer(missBy(e, 0.09));
        expect(e.outcome!.verdict, SplitVerdict.miss);
        expect(e.outcome!.tier, RevealTier.normal);
        expect(e.strikesLeft, 1);
        expect(e.isPlaying, isTrue);
        expect(e.locked, isTrue);
        expect(feedback.wrongs, 1);
        async.elapse(const Duration(milliseconds: 1199));
        expect(e.number, 7);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.number, 8);
        expect(e.outcome, isNull);

        e.answer(missBy(e, 0.2));
        expect(e.strikesLeft, 0);
        expect(e.state, RunState.down);
        expect(e.outcome, isNotNull, reason: 'the reveal stays while down');
        expect(feedback.wrongs, 2);
        async.elapse(const Duration(seconds: 5));
        expect(e.number, 8);
        e.dispose();
      });
    });

    test('the last shield lost on a near miss goes down after the reveal', () {
      fakeAsync((async) {
        final feedback = _Feedback();
        final e = engineAt(7, feedback: feedback)..start();
        e.answer(missBy(e, 0.2));
        async.elapse(LineSplitEngine.missPause);

        // 6% off a ±5% window: so close, the slow-motion reveal plays first.
        e.answer(missBy(e, 0.06));
        expect(e.outcome!.tier, RevealTier.close);
        expect(e.outcome!.headline, startsWith('SO CLOSE'));
        expect(e.strikesLeft, 0);
        expect(e.isPlaying, isTrue);
        expect(e.locked, isTrue);
        expect(feedback.wrongs, 1, reason: 'fail() buzzes when it goes down');

        // Pausing holds the reveal and the fall.
        async.elapse(const Duration(milliseconds: 1000));
        e.pause();
        async.elapse(const Duration(seconds: 10));
        e.resume();
        async.elapse(const Duration(milliseconds: 999));
        expect(e.state, RunState.playing);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.state, RunState.down);
        expect(feedback.wrongs, 2);
        expect(e.outcome, isNotNull);
        expect(e.number, 8, reason: 'no next question');
        e.dispose();
      });
    });

    test('a timeout breaks a shield', () {
      fakeAsync((async) {
        final e = engineAt(31)..start();
        expect(e.timeLimit, const Duration(seconds: 5));
        async.elapse(const Duration(milliseconds: 4999));
        expect(e.outcome, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.timedOut, isTrue);
        expect(e.outcome!.label, 'TIME');
        expect(e.outcome!.tier, RevealTier.normal);
        expect(e.strikesLeft, 1);
        expect(e.isPlaying, isTrue);
        async.elapse(LineSplitEngine.missPause);
        expect(e.number, 32);
        e.dispose();
      });
    });

    test('a hit is followed by the next question after 900 ms', () {
      fakeAsync((async) {
        final e = engineAt(1)..start();
        e.answer(e.question.target.position + 0.03);
        expect(e.outcome!.tier, RevealTier.normal);
        async.elapse(const Duration(milliseconds: 899));
        expect(e.number, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.number, 2);
        e.dispose();
      });
    });
  });

  group('reveal tiers', () {
    test('tier per verdict, and a near miss counts as close', () {
      const window = 5.0;
      expect(
        LineSplitEngine.tierOf(SplitVerdict.bullseye, 0.4, window),
        RevealTier.perfect,
      );
      expect(
        LineSplitEngine.tierOf(SplitVerdict.sharp, 1.6, window),
        RevealTier.close,
      );
      expect(
        LineSplitEngine.tierOf(SplitVerdict.hit, 3, window),
        RevealTier.normal,
      );
      expect(
        LineSplitEngine.tierOf(SplitVerdict.miss, 7.5, window),
        RevealTier.close,
      );
      expect(
        LineSplitEngine.tierOf(SplitVerdict.miss, 7.6, window),
        RevealTier.normal,
      );
      expect(
        LineSplitEngine.tierOf(SplitVerdict.time, double.infinity, window),
        RevealTier.normal,
      );
    });

    test('headlines', () {
      fakeAsync((async) {
        final e = engineAt(1)..start();
        e.answer(e.question.target.position + 0.004);
        expect(e.outcome!.tier, RevealTier.perfect);
        expect(e.outcome!.headline, 'PERFECT +0.4%');
        expect(e.outcome!.label, 'BULLSEYE +0.4%');
        async.elapse(LineSplitEngine.perfectPause);
        e.answer(e.question.target.position + 0.016);
        expect(e.outcome!.headline, 'SHARP +1.6%');
        expect(e.outcome!.nearMiss, isFalse);
        async.elapse(LineSplitEngine.closePause);
        e.answer(e.question.target.position + 0.07);
        expect(e.outcome!.headline, 'SO CLOSE +7.0%');
        expect(e.outcome!.nearMiss, isTrue);
        e.dispose();
      });
    });

    test('the next question waits for each tier', () {
      fakeAsync((async) {
        final e = engineAt(1)..start();
        expect(
          LineSplitEngine.closePause,
          LineSplitEngine.closeSlide + LineSplitEngine.closeHold,
        );
        void waits(double answer, RevealTier tier, Duration pause) {
          final number = e.number;
          // [answer] is relative to ½: the offset is kept on any target.
          e.answer(e.question.target.position + answer - 0.5);
          expect(e.outcome!.tier, tier);
          expect(LineSplitEngine.pauseFor(e.outcome!), pause);
          async.elapse(pause - const Duration(milliseconds: 1));
          expect(e.number, number, reason: '$tier');
          async.elapse(const Duration(milliseconds: 1));
          expect(e.number, number + 1, reason: '$tier');
        }

        waits(0.5, RevealTier.perfect, const Duration(milliseconds: 900));
        waits(0.515, RevealTier.close, const Duration(milliseconds: 2000));
        waits(0.53, RevealTier.normal, LineSplitEngine.hitPause);
        waits(0.57, RevealTier.close, const Duration(milliseconds: 2000));
        e.dispose();
      });
    });
  });

  group('scoring', () {
    test('hit, Sharp and Bullseye', () {
      fakeAsync((async) {
        final feedback = _Feedback();
        final e = engineAt(1, feedback: feedback)..start();

        e.answer(e.question.target.position + 0.009);
        expect(e.outcome!.verdict, SplitVerdict.bullseye);
        expect(e.outcome!.label, 'BULLSEYE +0.9%');
        expect(e.score, 20);
        async.elapse(LineSplitEngine.pauseFor(e.outcome!));

        e.answer(e.question.target.position + -0.015);
        expect(e.outcome!.verdict, SplitVerdict.sharp);
        expect(e.outcome!.label, 'SHARP −1.5%');
        expect(e.score, 35);
        async.elapse(LineSplitEngine.pauseFor(e.outcome!));

        e.answer(e.question.target.position + 0.03);
        expect(e.outcome!.verdict, SplitVerdict.hit);
        expect(e.outcome!.label, 'HIT +3.0%');
        expect(e.score, 45);
        async.elapse(LineSplitEngine.hitPause);

        // Exactly on the window edge still hits; past it misses.
        e.answer(e.question.target.position + 0.05);
        expect(e.outcome!.verdict, SplitVerdict.hit);
        async.elapse(LineSplitEngine.hitPause);
        e.answer(e.question.target.position + -0.049);
        expect(e.outcome!.verdict, SplitVerdict.hit);
        // The 5th hit in a row adds the app's streak bonus.
        expect(e.score, 45 + 10 + 10 + 20);
        async.elapse(LineSplitEngine.hitPause);

        e.answer(e.question.target.position + -0.06);
        expect(e.outcome!.verdict, SplitVerdict.miss);
        expect(e.outcome!.label, 'MISS −6.0%');
        expect(e.correct, 5);
        expect(feedback.rights, 5);
        e.dispose();
      });
    });

    test('press, slide, lift answers at the marker', () {
      fakeAsync((async) {
        final feedback = _Feedback();
        final e = engineAt(1, feedback: feedback)..start();
        e.grab(0.2);
        expect(feedback.taps, 1);
        e.aimAt(0.4);
        e.aimAt(0.502);
        expect(e.outcome, isNull);
        e.release();
        expect(e.outcome!.answer, 0.502);
        expect(e.aim.value, isNull);
        e.dispose();
      });
    });
  });

  group('pause and revive', () {
    test('pause keeps the remaining time', () {
      fakeAsync((async) {
        final e = engineAt(41)..start();
        expect(e.timeLimit, const Duration(seconds: 4));
        async.elapse(const Duration(milliseconds: 1500));
        e.pause();
        async.elapse(const Duration(seconds: 30));
        expect(e.timeLeft, const Duration(milliseconds: 2500));
        expect(e.outcome, isNull);
        e.resume();
        async.elapse(const Duration(milliseconds: 2499));
        expect(e.outcome, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(e.timedOut, isTrue);
        e.dispose();
      });
    });

    test('pause keeps the next-question delay', () {
      fakeAsync((async) {
        final e = engineAt(1)..start();
        e.answer(e.question.target.position + 0.0);
        async.elapse(const Duration(milliseconds: 500));
        e.pause();
        async.elapse(const Duration(seconds: 10));
        expect(e.number, 1);
        e.resume();
        async.elapse(const Duration(milliseconds: 400));
        expect(e.number, 2);
        e.dispose();
      });
    });

    test('revive(hold) leaves one strike and plays on after go()', () {
      fakeAsync((async) {
        final e = engineAt(31)..start();
        for (var i = 0; i < LineSplitEngine.maxStrikes; i++) {
          async.elapse(const Duration(seconds: 5));
          if (i < LineSplitEngine.maxStrikes - 1) {
            async.elapse(LineSplitEngine.missPause);
          }
        }
        expect(e.state, RunState.down);
        final number = e.number;
        final before = e.target;

        e.revive(hold: true);
        expect(e.state, RunState.resuming);
        expect(e.strikesLeft, 1);
        expect(e.number, number);
        expect(e.stage, SplitStage.of(number));
        expect(e.outcome, isNull);
        expect(e.target.sameAs(before), isFalse);
        expect(e.locked, isTrue);

        // Frozen while counting back in.
        async.elapse(const Duration(seconds: 20));
        expect(e.outcome, isNull);
        expect(e.timeLeft, const Duration(seconds: 5));

        e.go();
        expect(e.isPlaying, isTrue);
        e.answer(e.target.position);
        expect(e.outcome!.verdict, SplitVerdict.bullseye);
        async.elapse(LineSplitEngine.perfectPause);
        expect(e.number, number + 1);

        // One shield after a revive: the next miss goes down again.
        e.answer(missBy(e, 0.2));
        expect(e.state, RunState.down);
        e.dispose();
      });
    });
  });

  group('longer number lines', () {
    bool isWhole(double v) => (v - v.roundToDouble()).abs() < 1e-9;

    test('appear only from Q17, about 1 in 3', () {
      expect(
        questions(1, 16, seeds: 60).every((q) => q.target.units == 1),
        isTrue,
      );
      final later = questions(17, 90, seeds: 30);
      final multi = later.where((q) => q.target.units > 1).length;
      expect(multi / later.length, closeTo(1 / 3, 0.06));
    });

    test('0 · 1 · 2 · 3 lines from Q31; hidden middle ticks from Q43', () {
      for (final q in questions(17, 30, seeds: 80)) {
        if (q.target.isMultiUnit) {
          expect(q.target.units, 2);
          expect(q.target.unitTicks, isTrue);
        }
      }
      final mid = questions(
        31,
        42,
        seeds: 80,
      ).where((q) => q.target.isMultiUnit).toList();
      expect(mid.every((q) => q.target.unitTicks), isTrue);
      expect(mid.any((q) => q.target.units == 3), isTrue);
      final later = questions(
        43,
        90,
        seeds: 40,
      ).where((q) => q.target.isMultiUnit).toList();
      expect(later.any((q) => !q.target.unitTicks), isTrue);
      expect(later.any((q) => q.target.unitTicks), isTrue);
      expect(
        later.any((q) => q.target.units == 3 && q.target.unitTicks),
        isTrue,
      );
      expect(
        later.any((q) => q.target.units == 3 && !q.target.unitTicks),
        isTrue,
      );
    });

    test('longer lines use every denominator 2–8, with no favourite spot', () {
      final fractions = [
        for (final q in questions(17, 120, seeds: 80))
          if (q.target.isMultiUnit && q.target.denominator != null) q.target,
      ];
      expect({
        for (final t in fractions) t.denominator,
      }, LineSplitEngine.spanDenominators.toSet());
      expect(
        fractions.any((t) => (t.numerator, t.denominator) == (7, 6)),
        isTrue,
      );
      expect(
        fractions.any((t) => (t.numerator, t.denominator) == (11, 5)),
        isTrue,
      );
      // No single value on a 0–2 line takes more than 1 in 8 of them.
      final onTwo = [
        for (final t in fractions)
          if (t.units == 2) (t.shown * 1000).round(),
      ];
      final counts = <int, int>{};
      for (final v in onTwo) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      final most = counts.values.reduce(max);
      expect(most / onTwo.length, lessThan(1 / 8));
    });

    test('a value maps to its share of the line', () {
      expect(
        const SplitTarget.mixed(1, 1, 2, units: 2).position,
        closeTo(0.75, 1e-12),
      );
      expect(
        const SplitTarget.fraction(11, 8, units: 2).position,
        closeTo(0.6875, 1e-12),
      );
      expect(
        const SplitTarget.fraction(9, 4, units: 3, unitTicks: false).position,
        closeTo(0.75, 1e-12),
      );
      expect(
        const SplitTarget.decimal(1.6, units: 2).position,
        closeTo(0.8, 1e-12),
      );
      // The window and the error stay a share of the whole line.
      fakeAsync((async) {
        final e = engineAt(26)
          ..question = const SplitQuestion(
            target: SplitTarget.mixed(1, 1, 4, units: 2),
            line: SplitLine(degrees: 0, length: 0.9),
          )
          ..start();
        expect(e.window, 5.5);
        e.answer(0.625 + 0.016);
        expect(e.outcome!.error, closeTo(1.6, 1e-9));
        expect(e.outcome!.verdict, SplitVerdict.sharp);
        e.dispose();
      });
    });

    test('labels and subtitles', () {
      const mixed = SplitTarget.mixed(1, 1, 2, units: 2);
      expect(mixed.text, isNull);
      expect(mixed.isImproper, isFalse);
      expect(mixed.fractionText, '1 1/2');
      expect(mixed.subtitle, 'on 0 to 2');
      expect(mixed.spoken, '1 1/2 on a line from 0 to 2');
      const improper = SplitTarget.fraction(11, 8, units: 2);
      expect(improper.isImproper, isTrue);
      expect(improper.fractionText, '11/8');
      expect(const SplitTarget.decimal(1.6, units: 2).text, '1.6');
      expect(
        const SplitTarget.decimal(2.25, units: 3, unitTicks: false).subtitle,
        'on 0 to 3',
      );
    });

    test(
      'targets are inside the span, never whole, clear of ends and ticks',
      () {
        for (final q in questions(26, 120, seeds: 40)) {
          final t = q.target;
          if (!t.isMultiUnit) {
            continue;
          }
          expect(t.shown, greaterThan(0));
          expect(t.shown, lessThan(t.units));
          expect(isWhole(t.shown), isFalse, reason: '$t');
          final nearest = t.shown.roundToDouble();
          expect(
            (t.shown - nearest).abs(),
            greaterThanOrEqualTo(LineSplitEngine.wholeGap - 1e-9),
            reason: '$t',
          );
          // No fake ticks or "from the 1 end" on a longer line.
          expect(t.fromOne, isFalse);
          expect(t.ticks, isFalse);
          expect(q.ticks, isEmpty);
          expect(t.kind, isNot(TargetKind.percent));
          expect(q.line.length, inInclusiveRange(0.8, 0.92));
        }
      },
    );

    test('no target is a unit fraction back from the far end', () {
      const unitFractions = [1 / 2, 1 / 3, 1 / 4, 1 / 5, 1 / 8];
      for (final q in questions(26, 120, seeds: 40)) {
        final t = q.target;
        if (!t.isMultiUnit) {
          continue;
        }
        for (final f in unitFractions) {
          expect(
            (t.units - t.shown - f).abs(),
            greaterThan(1e-9),
            reason: '$t is ${f.toStringAsFixed(3)} from ${t.units}',
          );
        }
      }
      expect(LineSplitEngine.spanFractions(3), isNot(contains((11, 4))));
      expect(LineSplitEngine.spanFractions(3), contains((9, 4)));
      for (final f in [(7, 4), (3, 2), (5, 3), (15, 8)]) {
        expect(LineSplitEngine.spanFractions(2), isNot(contains(f)));
      }
      for (final f in [(5, 4), (9, 8), (6, 5), (4, 3), (11, 8)]) {
        expect(LineSplitEngine.spanFractions(2), contains(f));
      }
    });

    test('fractions prefer values past an inner whole number', () {
      final fractions = questions(26, 120, seeds: 60)
          .map((q) => q.target)
          .where((t) => t.isMultiUnit && t.kind == TargetKind.fraction)
          .toList();
      final past = fractions.where((t) => t.shown > 1).length;
      expect(past / fractions.length, greaterThan(0.65));
    });

    test('improper fractions from Q36; on hidden-tick lines from Q46', () {
      for (final q in questions(26, 35, seeds: 80)) {
        expect(q.target.isImproper, isFalse);
      }
      final mid = questions(36, 45, seeds: 80).map((q) => q.target).toList();
      expect(mid.any((t) => t.isImproper), isTrue);
      for (final t in mid.where((t) => t.isImproper)) {
        expect(t.unitTicks, isTrue, reason: 'hidden-tick improper from Q46');
      }
      final late = questions(46, 120, seeds: 60).map((q) => q.target);
      expect(late.any((t) => t.isImproper && !t.unitTicks), isTrue);
      for (final t in [...mid, ...late].where((t) => t.isImproper)) {
        expect(t.numerator!, greaterThan(t.denominator!));
        expect(t.numerator!.gcd(t.denominator!), 1);
        expect(LineSplitEngine.spanDenominators, contains(t.denominator));
        expect(isWhole(t.shown), isFalse);
        expect(t.shown, lessThan(t.units));
      }
    });

    test('mixed numbers before Q36 are written as whole plus a fraction', () {
      final targets = questions(26, 35, seeds: 80)
          .map((q) => q.target)
          .where((t) => t.isMultiUnit && t.kind == TargetKind.fraction);
      expect(targets.any((t) => t.whole > 0), isTrue);
      for (final t in targets) {
        expect(t.numerator!, lessThan(t.denominator!));
        expect(
          t.shown,
          closeTo(t.whole + t.numerator! / t.denominator!, 1e-12),
        );
      }
    });
  });
}
