import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/config.dart';
import 'package:logic_sprint/games/guess_color/guess_color_engine.dart';
import 'package:logic_sprint/games/memory_lane/memory_lane_engine.dart';
import 'package:logic_sprint/games/quick_math/quick_math_engine.dart';
import 'package:logic_sprint/games/rocket_launch/rocket_launch_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/games/round_screen.dart';
import 'package:logic_sprint/models/game.dart';

const _frame = Duration(milliseconds: 16);
const _ms = Duration(milliseconds: 1);

// Engines are built inside fakeAsync so their clocks are the fake one.
GuessColorEngine _guess() =>
    GuessColorEngine(difficulty: Difficulty.medium, random: Random(1));

QuickMathEngine _math() =>
    QuickMathEngine(difficulty: Difficulty.easy, random: Random(3));

MemoryLaneEngine _memory() =>
    MemoryLaneEngine(difficulty: Difficulty.easy, random: Random(7));

RocketLaunchEngine _rocket() =>
    RocketLaunchEngine(difficulty: Difficulty.medium, random: Random(1));

/// Plays correct Guess Color picks until word [n] is showing.
void _advanceTo(GuessColorEngine e, FakeAsync async, int n) {
  while (e.number < n) {
    e.pick(e.item.target);
    async.elapse(const Duration(milliseconds: 250));
  }
}

InkColor _wrongColor(GuessColorEngine e) =>
    InkColor.values.firstWhere((color) => color != e.item.target);

int _wrongAnswer(QuickMathEngine e) =>
    e.problem.options.firstWhere((o) => o != e.problem.answer);

/// Lead-in plus every lit tile and the gaps between them.
Duration _playback(int length) =>
    Duration(milliseconds: 600 + length * 450 + (length - 1) * 150);

void _crash(RocketLaunchEngine engine) {
  engine.asteroids.add(
    Asteroid(x: engine.rocketX, y: 0.85, size: 40, speed: 0),
  );
  engine.tick(_frame);
}

void main() {
  group('RoundEngine pause', () {
    test('pause and resume only apply to a live / paused run', () {
      fakeAsync((async) {
        final e = _math();
        e.pause();
        expect(e.state, RunState.ready);
        e.start();
        e.resume();
        expect(e.state, RunState.playing);
        e.pause();
        expect(e.state, RunState.paused);
        expect(e.isPaused, isTrue);
        expect(e.isPlaying, isFalse);
        e.pause();
        e.resume();
        expect(e.state, RunState.playing);

        e.answer(_wrongAnswer(e));
        e.pause();
        expect(e.state, RunState.down, reason: 'a down run is not paused');
        e.dispose();
      });
    });

    test('the run stopwatch does not advance while paused', () {
      fakeAsync((async) {
        final e = _math()..start();
        async.elapse(const Duration(seconds: 2));
        e.pause();
        async.elapse(const Duration(minutes: 5));
        expect(e.elapsed, const Duration(seconds: 2));
        e.resume();
        async.elapse(const Duration(seconds: 1));
        e.finish();
        expect(e.result!.duration, const Duration(seconds: 3));
        e.dispose();
      });
    });

    test('finishing a paused run cancels every timer', () {
      fakeAsync((async) {
        final e = _guess()..start();
        _advanceTo(e, async, 13);
        e.pause();
        e.finish();
        expect(e.isFinished, isTrue);
        expect(async.pendingTimers, isEmpty);
        e.dispose();
      });
    });
  });

  group('Guess Color pause', () {
    test('10 s away mid-countdown keeps the run and the time left', () {
      fakeAsync((async) {
        final e = _guess()..start();
        _advanceTo(e, async, 13);
        expect(e.timeLimit, const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 1));
        expect(e.timeLeft, const Duration(seconds: 2));

        e.pause();
        async.elapse(const Duration(seconds: 10));
        expect(e.state, RunState.paused);
        expect(e.timedOut, isFalse);
        expect(e.timeLeft, const Duration(seconds: 2));
        expect(e.locked, isTrue);
        e.pick(e.item.target);
        expect(e.picked, isNull, reason: 'no picks while paused');

        e.resume();
        expect(e.timeLeft, const Duration(seconds: 2));
        async.elapse(const Duration(milliseconds: 1900));
        expect(e.state, RunState.playing);
        expect(e.timeLeft, const Duration(milliseconds: 100));
        async.elapse(const Duration(milliseconds: 200));
        expect(e.state, RunState.down);
        expect(e.timedOut, isTrue);
        e.dispose();
      });
    });

    test('the pending next word waits out only its remaining delay', () {
      fakeAsync((async) {
        final e = _guess()..start();
        e.pick(e.item.target);
        async.elapse(const Duration(milliseconds: 100));
        e.pause();
        async.elapse(const Duration(seconds: 10));
        expect(e.number, 1);
        e.resume();
        async.elapse(const Duration(milliseconds: 149));
        expect(e.number, 1);
        async.elapse(_ms);
        expect(e.number, 2);
        expect(e.picked, isNull);
        e.dispose();
      });
    });
  });

  group('Quick Math pause', () {
    test('the next problem waits while paused', () {
      fakeAsync((async) {
        final e = _math()..start();
        e.answer(e.problem.answer);
        async.elapse(const Duration(milliseconds: 100));
        e.pause();
        async.elapse(const Duration(seconds: 30));
        expect(e.number, 1);
        e.resume();
        async.elapse(const Duration(milliseconds: 180));
        expect(e.number, 2);
        expect(e.locked, isFalse);
        e.dispose();
      });
    });
  });

  group('Memory Lane pause', () {
    test('a pause mid-playback replays the pattern from the start', () {
      fakeAsync((async) {
        final e = _memory()..start();
        final pattern = e.sequence;
        async.elapse(const Duration(milliseconds: 1200)); // tile 2 lit
        expect(e.litTile, pattern[1]);

        e.pause();
        expect(e.litTile, isNull);
        async.elapse(const Duration(seconds: 20));
        expect(e.phase, MemoryPhase.watch);
        expect(e.litTile, isNull);

        e.resume();
        async.elapse(const Duration(milliseconds: 600));
        expect(e.litTile, pattern[0]);
        async.elapse(_playback(3) - const Duration(milliseconds: 600));
        expect(e.canTap, isTrue);
        expect(e.sequence, pattern);
        e.dispose();
      });
    });

    test('a pause while repeating keeps the taps done so far', () {
      fakeAsync((async) {
        final e = _memory()..start();
        async.elapse(_playback(3));
        final pattern = e.sequence;
        e.tap(pattern[0]);
        e.pause();
        expect(e.canTap, isFalse);
        async.elapse(const Duration(seconds: 20));
        e.resume();
        expect(e.phase, MemoryPhase.repeat);
        expect(e.stepsDone, 1);
        e
          ..tap(pattern[1])
          ..tap(pattern[2]);
        expect(e.level, 2);
        e.dispose();
      });
    });

    test('a pause during the level-up delay resumes it', () {
      fakeAsync((async) {
        final e = _memory()..start();
        async.elapse(_playback(3));
        e.sequence.forEach(e.tap);
        async.elapse(const Duration(milliseconds: 500));
        e.pause();
        async.elapse(const Duration(seconds: 20));
        expect(e.sequenceLength, 3);
        e.resume();
        async.elapse(const Duration(milliseconds: 300));
        expect(e.sequenceLength, 4);
        expect(e.phase, MemoryPhase.watch);
        e.dispose();
      });
    });
  });

  group('Rocket Launch pause', () {
    test('the field stands still while paused and resumes without a jump', () {
      final e = _rocket()..start();
      e.tick(_frame);
      e.pause();
      final time = e.flightTime;
      final rock = Asteroid(x: 0.2, y: 0.3, size: 40, speed: 1);
      e
        ..asteroids.add(rock)
        ..steerTo(0.9);
      for (var i = 0; i < 100; i++) {
        e.tick(_frame);
      }
      expect(e.flightTime, time);
      expect(rock.y, 0.3);
      expect(e.targetX, 0.5, reason: 'no steering while paused');

      e.resume();
      // A long first frame after the break still moves at most one step.
      e.tick(const Duration(seconds: 30));
      expect(e.flightTime - time, const Duration(milliseconds: 50));
      expect(rock.y, closeTo(0.35, 1e-9));
      e.dispose();
    });
  });

  group('revives', () {
    test('Quick Math: three revives, then no more', () {
      fakeAsync((async) {
        final e = _math()..start();
        for (var i = 1; i <= AppConfig.maxRevivesPerRun; i++) {
          e.answer(_wrongAnswer(e));
          expect(e.canRevive, isTrue);
          final number = e.number;
          e.revive();
          expect(e.state, RunState.playing);
          expect(e.revives, i);
          expect(e.number, number + 1, reason: 'a fresh problem');
          expect(e.picked, isNull);
          e.answer(e.problem.answer);
          async.elapse(const Duration(milliseconds: 300));
        }
        e.answer(_wrongAnswer(e));
        expect(e.state, RunState.down);
        expect(e.canRevive, isFalse);
        e.revive();
        expect(e.state, RunState.down);
        expect(e.revives, 3);
        e.dispose();
      });
    });

    test('Guess Color: three revives, each a fresh word at the same stage', () {
      fakeAsync((async) {
        final e = _guess()..start();
        _advanceTo(e, async, 14);
        for (var i = 1; i <= 3; i++) {
          final failed = e.item;
          e.pick(_wrongColor(e));
          async.elapse(const Duration(seconds: 3));
          expect(e.state, RunState.down);
          e.revive();
          expect(e.state, RunState.playing);
          expect(e.revives, i);
          expect(e.number, 14);
          expect(e.item, isNot(same(failed)));
          expect(e.picked, isNull);
          expect(e.timeLeft, e.timeLimit);
        }
        e.pick(e.item.target);
        expect(e.correct, 14);
        async.elapse(const Duration(milliseconds: 250));
        expect(e.number, 15);
        e.dispose();
      });
    });

    test('Memory Lane: three revives, each replays the pattern', () {
      fakeAsync((async) {
        final e = _memory()..start();
        async.elapse(_playback(3));
        final pattern = e.sequence;
        for (var i = 1; i <= 3; i++) {
          e.tap((e.sequence[e.stepsDone] + 1) % e.tileCount);
          expect(e.state, RunState.down);
          e.revive();
          expect(e.phase, MemoryPhase.watch);
          expect(e.wrongTile, isNull);
          expect(e.sequence, pattern);
          async.elapse(_playback(3));
          expect(e.canTap, isTrue);
        }
        expect(e.revives, 3);
        e.sequence.forEach(e.tap);
        expect(e.level, 2);
        e.dispose();
      });
    });

    test('Rocket Launch: three revives, each clears rocks with a shield', () {
      final e = _rocket()..start();
      for (var i = 1; i <= 3; i++) {
        _crash(e);
        expect(e.state, RunState.down);
        e.revive();
        expect(e.asteroids, isEmpty);
        expect(e.invulnerable, isTrue);
        _crash(e);
        expect(e.isPlaying, isTrue, reason: 'shielded');
        e.asteroids.clear();
        for (var t = Duration.zero; t < RocketLaunchEngine.reviveShield;) {
          e.tick(_frame);
          t += _frame;
        }
        e.asteroids.clear();
        expect(e.invulnerable, isFalse);
      }
      _crash(e);
      expect(e.state, RunState.down);
      expect(e.canRevive, isFalse);
      e.dispose();
    });
  });

  group('offersRevive', () {
    /// A Quick Math run that went down with [points] points.
    QuickMathEngine downAt(int points) {
      final e = _math()..start();
      e.score = points;
      e.answer(_wrongAnswer(e));
      return e;
    }

    test('not below reviveMinScore', () {
      fakeAsync((async) {
        final e = downAt(AppConfig.reviveMinScore - 1);
        expect(
          offersRevive(e, online: true, hearts: 5, adReady: true),
          isFalse,
        );
        e.dispose();
        final f = downAt(AppConfig.reviveMinScore);
        expect(offersRevive(f, online: true, hearts: 0, adReady: true), isTrue);
        expect(
          offersRevive(f, online: true, hearts: 1, adReady: false),
          isTrue,
        );
        expect(
          offersRevive(f, online: true, hearts: 0, adReady: false),
          isFalse,
        );
        f.dispose();
      });
    });

    test('never offline, even with hearts and an ad', () {
      fakeAsync((async) {
        final e = downAt(500);
        expect(offersRevive(e, online: true, hearts: 3, adReady: true), isTrue);
        expect(
          offersRevive(e, online: false, hearts: 3, adReady: true),
          isFalse,
        );
        e.dispose();
      });
    });

    test('not after the third revive', () {
      fakeAsync((async) {
        final e = downAt(100);
        for (var i = 0; i < AppConfig.maxRevivesPerRun; i++) {
          expect(
            offersRevive(e, online: true, hearts: 3, adReady: true),
            isTrue,
          );
          e.revive();
          e.answer(_wrongAnswer(e));
        }
        expect(e.state, RunState.down);
        expect(
          offersRevive(e, online: true, hearts: 3, adReady: true),
          isFalse,
        );
        e.dispose();
      });
    });

    test('not while playing or paused', () {
      fakeAsync((async) {
        final e = _math()..start();
        e.score = 500;
        expect(
          offersRevive(e, online: true, hearts: 3, adReady: true),
          isFalse,
        );
        e.pause();
        expect(
          offersRevive(e, online: true, hearts: 3, adReady: true),
          isFalse,
        );
        e.dispose();
      });
    });
  });

  group('ReviveOffer', () {
    Future<List<String>> pumpOffer(
      WidgetTester tester, {
      int hearts = 0,
      bool adReady = true,
      int revives = 0,
      bool calm = false,
    }) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: calm),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: [
                ReviveOffer(
                  score: 120,
                  revives: revives,
                  hearts: hearts,
                  adReady: adReady,
                  onHeart: () => calls.add('heart'),
                  onWatch: () => calls.add('watch'),
                  onEnd: () => calls.add('end'),
                ),
              ],
            ),
          ),
        ),
      );
      return calls;
    }

    Finder text(String pattern) =>
        find.textContaining(RegExp(pattern, caseSensitive: false));

    double? ringValue(WidgetTester tester) => tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .value;

    testWidgets('times out after 5 s and ends the run', (tester) async {
      final calls = await pumpOffer(tester);
      expect(text('^5\$'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(text('^3\$'), findsOneWidget);
      expect(ringValue(tester), closeTo(0.6, 0.02), reason: 'ring drains');
      await tester.pump(const Duration(milliseconds: 2999));
      expect(calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, ['end']);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, ['end'], reason: 'ends once');
    });

    testWidgets('still times out after 5 s with reduce motion', (tester) async {
      final calls = await pumpOffer(tester, calm: true);
      await tester.pump(const Duration(seconds: 1));
      expect(text('^4\$'), findsOneWidget);
      expect(ringValue(tester), 1, reason: 'the ring does not drain');
      await tester.pump(const Duration(seconds: 4));
      expect(calls, ['end']);
    });

    testWidgets('watching the ad stops the countdown', (tester) async {
      final calls = await pumpOffer(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(text('watch ad'));
      await tester.pump(const Duration(seconds: 30));
      expect(calls, ['watch']);
      await tester.tap(text('end run'));
      expect(calls, ['watch'], reason: 'buttons lock after a choice');
    });

    testWidgets('heart button only with hearts; ad button only when ready', (
      tester,
    ) async {
      await pumpOffer(tester, hearts: 2, adReady: false, revives: 1);
      expect(text('2 left'), findsOneWidget);
      expect(text('watch ad'), findsNothing);
      expect(text('revived 1/3'), findsOneWidget);
      expect(text('end run'), findsOneWidget);

      final calls = await pumpOffer(tester, hearts: 0, adReady: true);
      expect(text('left'), findsNothing);
      expect(text('revived'), findsNothing);
      await tester.pump();
      await tester.tap(text('watch ad'));
      expect(calls, ['watch']);
    });

    testWidgets('using a heart stops the countdown', (tester) async {
      final calls = await pumpOffer(tester, hearts: 1);
      await tester.tap(text('1 left'));
      await tester.pump(const Duration(seconds: 10));
      expect(calls, ['heart']);
    });
  });

  group('PausableTimer', () {
    test('fires after its duration minus nothing spent on hold', () {
      fakeAsync((async) {
        var fired = 0;
        final timer = PausableTimer(const Duration(seconds: 3), () => fired++);
        async.elapse(const Duration(seconds: 1));
        timer.pause();
        expect(timer.isPaused, isTrue);
        expect(timer.remaining, const Duration(seconds: 2));
        async.elapse(const Duration(hours: 1));
        expect(fired, 0);
        timer
          ..resume()
          ..resume();
        async.elapse(const Duration(milliseconds: 1999));
        expect(fired, 0);
        async.elapse(_ms);
        expect(fired, 1);
        expect(timer.isActive, isFalse);
        timer.resume();
        async.elapse(const Duration(seconds: 5));
        expect(fired, 1);
      });
    });

    test('cancel works while running or paused', () {
      fakeAsync((async) {
        var fired = 0;
        PausableTimer(const Duration(seconds: 1), () => fired++).cancel();
        final paused = PausableTimer(const Duration(seconds: 1), () => fired++)
          ..pause()
          ..cancel()
          ..resume();
        async.elapse(const Duration(seconds: 5));
        expect(fired, 0);
        expect(paused.isActive, isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
