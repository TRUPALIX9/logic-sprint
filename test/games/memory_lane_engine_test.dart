import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/memory_lane/memory_lane_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

// Built inside fakeAsync so the run clock is the fake one.
MemoryLaneEngine _engine([Difficulty difficulty = Difficulty.easy]) =>
    MemoryLaneEngine(difficulty: difficulty, random: Random(7));

/// Lead-in plus every lit tile and the gaps between them.
Duration _playback(int length) =>
    Duration(milliseconds: 600 + length * 450 + (length - 1) * 150);

/// Any tile that isn't the next expected one.
int _wrongTile(MemoryLaneEngine engine) =>
    (engine.sequence[engine.stepsDone] + 1) % engine.tileCount;

void _repeatAll(MemoryLaneEngine engine) {
  for (final tile in engine.sequence) {
    engine.tap(tile);
  }
}

void main() {
  test('grid size and starting length follow difficulty', () {
    for (final (difficulty, n) in [
      (Difficulty.easy, 3),
      (Difficulty.medium, 4),
      (Difficulty.hard, 5),
    ]) {
      final engine = _engine(difficulty);
      expect(engine.gridSize, n);
      expect(engine.tileCount, n * n);
      expect(engine.sequenceLength, n);
      expect(engine.level, 1);
      expect(engine.sequence.every((t) => t >= 0 && t < n * n), isTrue);
      engine.dispose();
    }
  });

  test('plays the sequence, then switches to repeat', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      expect(engine.state, RunState.playing);
      expect(engine.phase, MemoryPhase.watch);
      expect(engine.litTile, isNull);

      async.elapse(const Duration(milliseconds: 600));
      expect(engine.litTile, engine.sequence[0]);
      async.elapse(const Duration(milliseconds: 450));
      expect(engine.litTile, isNull);
      async.elapse(const Duration(milliseconds: 150));
      expect(engine.litTile, engine.sequence[1]);

      async.elapse(_playback(3) - const Duration(milliseconds: 1200));
      expect(engine.phase, MemoryPhase.repeat);
      expect(engine.litTile, isNull);
      expect(engine.canTap, isTrue);
      engine.dispose();
    });
  });

  test('taps are ignored while watching', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      async.elapse(const Duration(milliseconds: 700));
      engine
        ..tap(engine.sequence[0])
        ..tap(_wrongTile(engine));
      expect(engine.canTap, isFalse);
      expect(engine.stepsDone, 0);
      expect(engine.correct, 0);
      expect(engine.score, 0);
      expect(engine.state, RunState.playing);
      engine.dispose();
    });
  });

  test('a full correct repeat scores, levels up and grows the sequence', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      async.elapse(_playback(3));
      final first = engine.sequence;

      engine.tap(first[0]);
      expect(engine.stepsDone, 1);
      expect(engine.correctTile, first[0]);
      expect(engine.score, 10);
      engine
        ..tap(first[1])
        ..tap(first[2]);

      expect(engine.correct, 3);
      expect(engine.score, 3 * 10 + 20);
      expect(engine.level, 2);
      expect(engine.canTap, isFalse);

      async.elapse(const Duration(milliseconds: 800));
      expect(engine.phase, MemoryPhase.watch);
      expect(engine.sequenceLength, 4);
      expect(engine.stepsDone, 0);

      async.elapse(_playback(4));
      expect(engine.phase, MemoryPhase.repeat);
      engine.dispose();
    });
  });

  test('levels keep coming, one tile longer each time', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      for (var level = 1; level <= 5; level++) {
        expect(engine.level, level);
        expect(engine.sequenceLength, level + 2);
        async.elapse(_playback(engine.sequenceLength));
        _repeatAll(engine);
        async.elapse(const Duration(milliseconds: 800));
      }
      // 3+4+5+6+7 taps; +20 per level and +20 per 5-tap streak.
      expect(engine.level, 6);
      expect(engine.sequenceLength, 8);
      expect(engine.correct, 25);
      expect(engine.score, 25 * 10 + 5 * 20 + 5 * 20);
      expect(engine.state, RunState.playing);
      engine.dispose();
    });
  });

  test('a wrong tap takes the run down with no replay', () {
    fakeAsync((async) {
      final engine = _engine(Difficulty.medium)..start();
      async.elapse(_playback(4));
      final pattern = engine.sequence;

      engine.tap(pattern[0]);
      final wrongTile = _wrongTile(engine);
      engine.tap(wrongTile);
      expect(engine.state, RunState.down);
      expect(engine.canRevive, isTrue);
      expect(engine.wrongTile, wrongTile);
      expect(engine.correctTile, isNull);
      expect(engine.score, 10);
      expect(engine.canTap, isFalse);
      expect(async.pendingTimers, isEmpty);

      async.elapse(const Duration(seconds: 10));
      expect(engine.phase, MemoryPhase.repeat);
      expect(engine.wrongTile, wrongTile);
      expect(engine.sequence, pattern);
      engine.tap(pattern[1]);
      expect(engine.correct, 1);
      engine.dispose();
    });
  });

  test('revive replays the same pattern and taps count again', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      async.elapse(_playback(3));
      final pattern = engine.sequence;
      engine.tap(_wrongTile(engine));
      expect(engine.state, RunState.down);

      engine.revive();
      expect(engine.state, RunState.playing);
      expect(engine.phase, MemoryPhase.watch);
      expect(engine.wrongTile, isNull);
      expect(engine.sequence, pattern);
      expect(engine.level, 1);

      async.elapse(const Duration(milliseconds: 600));
      expect(engine.litTile, pattern[0]);
      async.elapse(_playback(3) - const Duration(milliseconds: 600));
      expect(engine.canTap, isTrue);

      _repeatAll(engine);
      expect(engine.correct, 3);
      expect(engine.level, 2);
      engine.dispose();
    });
  });

  test('finish builds a result with the playing time and stops timers', () {
    fakeAsync((async) {
      final engine = _engine(Difficulty.hard)..start();
      async.elapse(_playback(5));
      engine.tap(engine.sequence[0]);
      engine.tap(_wrongTile(engine));

      // Time spent down doesn't count.
      async.elapse(const Duration(seconds: 5));
      engine.revive();
      async.elapse(const Duration(seconds: 2));
      engine.finish();

      expect(engine.isFinished, isTrue);
      expect(async.pendingTimers, isEmpty);
      final result = engine.result!;
      expect(result.game, GameId.memoryLane);
      expect(result.difficulty, Difficulty.hard);
      expect(result.score, 10);
      expect(result.correct, 1);
      expect(result.duration, _playback(5) + const Duration(seconds: 2));

      async.elapse(const Duration(seconds: 5));
      engine.tap(engine.sequence[0]);
      expect(engine.correct, 1);
      engine.dispose();
    });
  });
}
