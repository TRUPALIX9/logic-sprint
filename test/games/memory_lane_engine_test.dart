import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/memory_lane/memory_lane_engine.dart';
import 'package:logic_sprint/models/game.dart';

MemoryLaneEngine _engine([Difficulty difficulty = Difficulty.easy]) =>
    MemoryLaneEngine(difficulty: difficulty, random: Random(7));

/// Lead-in plus every lit tile and the gaps between them.
Duration _playback(int length) =>
    Duration(milliseconds: 600 + length * 450 + (length - 1) * 150);

/// Any tile that isn't the next expected one.
int _wrongTile(MemoryLaneEngine engine) =>
    (engine.sequence[engine.stepsDone] + 1) % engine.tileCount;

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
      expect(engine.wrong, 0);
      expect(engine.score, 0);
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

  test('a wrong tap counts a miss and replays the same length', () {
    fakeAsync((async) {
      final engine = _engine(Difficulty.medium)..start();
      async.elapse(_playback(4));

      engine.tap(engine.sequence[0]);
      final wrongTile = _wrongTile(engine);
      engine.tap(wrongTile);
      expect(engine.wrong, 1);
      expect(engine.wrongTile, wrongTile);
      expect(engine.score, 10);
      expect(engine.canTap, isFalse);

      async.elapse(const Duration(milliseconds: 600));
      expect(engine.phase, MemoryPhase.watch);
      expect(engine.wrongTile, isNull);
      expect(engine.stepsDone, 0);
      expect(engine.sequenceLength, 4);
      expect(engine.level, 1);

      async.elapse(_playback(4));
      expect(engine.phase, MemoryPhase.repeat);
      engine.dispose();
    });
  });

  test('the round finishes after 30 s and stops every timer', () {
    fakeAsync((async) {
      final engine = _engine(Difficulty.hard)..start();
      async.elapse(_playback(5));
      engine.tap(engine.sequence[0]);
      expect(async.pendingTimers, isNotEmpty);

      async.elapse(const Duration(seconds: 30));
      expect(engine.isFinished, isTrue);
      expect(engine.result!.game, GameId.memoryLane);
      expect(engine.result!.score, 10);
      expect(async.pendingTimers, isEmpty);

      engine.tap(engine.sequence[1]);
      expect(engine.correct, 1);
      engine.dispose();
    });
  });
}
