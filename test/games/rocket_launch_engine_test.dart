import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/rocket_launch/rocket_launch_engine.dart';
import 'package:logic_sprint/models/game.dart';

const _frame = Duration(milliseconds: 16);

RocketLaunchEngine _engine({
  Difficulty difficulty = Difficulty.medium,
  int seed = 1,
}) => RocketLaunchEngine(difficulty: difficulty, random: Random(seed));

/// A rock placed by hand, so tests control every hit.
Asteroid _rock({required double x, required double y, double speed = 0}) =>
    Asteroid(x: x, y: y, size: 40, speed: speed);

void _run(RocketLaunchEngine engine, Duration time) {
  for (var t = Duration.zero; t < time; t += _frame) {
    engine.tick(_frame);
  }
}

void main() {
  test('steering clamps the target to the field', () {
    final engine = _engine();
    expect(engine.rocketX, 0.5);
    engine.steerTo(-1);
    expect(engine.targetX, RocketLaunchEngine.minX);
    engine.steerTo(2);
    expect(engine.targetX, RocketLaunchEngine.maxX);
    engine.steerTo(0.3);
    expect(engine.targetX, 0.3);
    expect(engine.rocketX, 0.5, reason: 'the rocket only moves on tick');
    engine.dispose();
  });

  test('the rocket follows the target at a capped speed', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      engine.steerTo(0.95);
      engine.tick(_frame);

      final moved = engine.rocketX - 0.5;
      expect(moved, greaterThan(0));
      expect(
        moved,
        lessThanOrEqualTo(RocketLaunchEngine.steerSpeed * 0.016 + 1e-9),
      );

      _run(engine, const Duration(seconds: 1));
      expect(engine.rocketX, closeTo(0.95, 0.001));

      engine.steerTo(0.2);
      _run(engine, const Duration(seconds: 1));
      expect(engine.rocketX, closeTo(0.2, 0.001));
      engine.dispose();
    });
  });

  test('a collision is wrong, floors the score and removes the rock', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      final rock = _rock(x: 0.52, y: 0.84);
      engine.asteroids.add(rock);
      engine.tick(_frame);

      expect(engine.wrong, 1);
      expect(engine.score, 0);
      expect(engine.asteroids, isNot(contains(rock)));
      expect(engine.flashing, isTrue);
      engine.dispose();
    });
  });

  test('a dodge scores, and a later hit costs the penalty', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      final passing = _rock(x: 0.9, y: 0.99, speed: 1);
      engine.asteroids.add(passing);
      engine.tick(_frame);

      expect(engine.correct, 1);
      expect(engine.score, 10);
      expect(engine.asteroids, isNot(contains(passing)));

      engine.asteroids.add(_rock(x: 0.5, y: 0.85));
      engine.tick(_frame);
      expect(engine.wrong, 1);
      expect(engine.score, 0);
      engine.dispose();
    });
  });

  test('a rock beside the rocket passes without a hit', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      engine.asteroids.add(_rock(x: 0.8, y: 0.85));
      engine.tick(_frame);
      expect(engine.wrong, 0);
      expect(engine.asteroids, hasLength(1));
      engine.dispose();
    });
  });

  test('tick is a no-op before start', () {
    final engine = _engine();
    engine
      ..asteroids.add(_rock(x: 0.5, y: 0.85))
      ..steerTo(0.9);
    _run(engine, const Duration(seconds: 2));
    expect(engine.elapsed, Duration.zero);
    expect(engine.spawned, 0);
    expect(engine.wrong, 0);
    expect(engine.rocketX, 0.5);
    expect(engine.asteroids, hasLength(1));
    engine.dispose();
  });

  test('the round finishes after 30 s and tick stops', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      async.elapse(const Duration(seconds: 30));
      expect(engine.isFinished, isTrue);

      engine.asteroids.add(_rock(x: 0.5, y: 0.85));
      final spawned = engine.spawned;
      engine
        ..steerTo(0.2)
        ..tick(_frame);
      expect(engine.wrong, 0);
      expect(engine.spawned, spawned);
      expect(engine.targetX, 0.5);
      expect(engine.rocketX, 0.5);
      expect(engine.result, isNotNull);
      engine.dispose();
    });
  });

  test('later in the round spawns more and falls faster', () {
    fakeAsync((async) {
      final engine = _engine(seed: 7)..start();
      final early = engine.speedFactor;

      _run(engine, const Duration(seconds: 10));
      final firstTen = engine.spawned;
      final earlySpeed = engine.asteroids.map((r) => r.speed).reduce(max);

      _run(engine, const Duration(seconds: 10));
      final middleTen = engine.spawned - firstTen;

      _run(engine, const Duration(seconds: 10));
      final lastTen = engine.spawned - firstTen - middleTen;
      final lateSpeed = engine.asteroids.map((r) => r.speed).reduce(min);

      expect(middleTen, greaterThan(firstTen));
      expect(lastTen, greaterThan(middleTen));
      expect(engine.speedFactor, greaterThan(early * 2));
      expect(lateSpeed, greaterThan(earlySpeed));
      engine.dispose();
    });
  });

  test('difficulty is ignored', () {
    fakeAsync((async) {
      int spawnedAs(Difficulty difficulty) {
        final engine = _engine(difficulty: difficulty, seed: 3)..start();
        _run(engine, const Duration(seconds: 20));
        final spawned = engine.spawned;
        engine.dispose();
        return spawned;
      }

      final easy = spawnedAs(Difficulty.easy);
      expect(spawnedAs(Difficulty.medium), easy);
      expect(spawnedAs(Difficulty.hard), easy);
    });
  });
}
