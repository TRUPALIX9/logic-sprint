import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/rocket_launch/rocket_launch_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

const _frame = Duration(milliseconds: 16);

RocketLaunchEngine _engine({int seed = 1}) =>
    RocketLaunchEngine(difficulty: Difficulty.medium, random: Random(seed));

/// A rock placed by hand, so tests control every hit.
Asteroid _rock({required double x, required double y, double speed = 0}) =>
    Asteroid(x: x, y: y, size: 40, speed: speed);

void _run(RocketLaunchEngine engine, Duration time) {
  for (var t = Duration.zero; t < time; t += _frame) {
    engine.tick(_frame);
  }
}

/// Drops a rock right on the rocket and ticks once.
void _crash(RocketLaunchEngine engine) {
  engine.asteroids.add(_rock(x: engine.rocketX, y: 0.85));
  engine.tick(_frame);
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
    final engine = _engine()..start();
    engine
      ..steerTo(0.95)
      ..tick(_frame);

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

  test('a collision sends the run down without a penalty', () {
    final engine = _engine()..start();
    engine.asteroids.add(_rock(x: 0.9, y: 0.99, speed: 1));
    engine.tick(_frame);
    expect(engine.score, 10);

    engine.asteroids.add(_rock(x: 0.52, y: 0.84));
    engine.tick(_frame);
    expect(engine.state, RunState.down);
    expect(engine.isPlaying, isFalse);
    expect(engine.score, 10);
    engine.dispose();
  });

  test('a dodge scores', () {
    final engine = _engine()..start();
    final passing = _rock(x: 0.9, y: 0.99, speed: 1);
    engine.asteroids.add(passing);
    engine.tick(_frame);

    expect(engine.correct, 1);
    expect(engine.score, 10);
    expect(engine.asteroids, isNot(contains(passing)));
    expect(engine.isPlaying, isTrue);
    engine.dispose();
  });

  test('a rock beside the rocket passes without a hit', () {
    final engine = _engine()..start();
    engine.asteroids.add(_rock(x: 0.8, y: 0.85));
    engine.tick(_frame);
    expect(engine.isPlaying, isTrue);
    expect(engine.asteroids, hasLength(1));
    engine.dispose();
  });

  test('tick is a no-op before start', () {
    final engine = _engine();
    engine
      ..asteroids.add(_rock(x: 0.5, y: 0.85))
      ..steerTo(0.9);
    _run(engine, const Duration(seconds: 2));
    expect(engine.state, RunState.ready);
    expect(engine.flightTime, Duration.zero);
    expect(engine.spawned, 0);
    expect(engine.rocketX, 0.5);
    expect(engine.asteroids, hasLength(1));
    engine.dispose();
  });

  test('tick and steering are ignored while down', () {
    final engine = _engine()..start();
    _crash(engine);
    expect(engine.state, RunState.down);

    final time = engine.flightTime;
    final falling = _rock(x: 0.2, y: 0.3, speed: 1);
    engine
      ..asteroids.add(falling)
      ..steerTo(0.9);
    _run(engine, const Duration(seconds: 2));
    expect(engine.flightTime, time);
    expect(falling.y, 0.3);
    expect(engine.targetX, 0.5);
    expect(engine.spawned, 0);
    engine.dispose();
  });

  test('revive clears the sky and shields the rocket briefly', () {
    final engine = _engine()..start();
    engine.asteroids.addAll([_rock(x: 0.3, y: 0.6), _rock(x: 0.7, y: 0.2)]);
    _crash(engine);
    expect(engine.canRevive, isTrue);

    engine.revive();
    expect(engine.state, RunState.playing);
    expect(engine.asteroids, isEmpty);
    expect(engine.invulnerable, isTrue);

    // Rocks pass straight through during the shield.
    _crash(engine);
    expect(engine.isPlaying, isTrue);
    engine.asteroids.clear();
    _run(engine, const Duration(milliseconds: 1400));
    expect(engine.isPlaying, isTrue);
    expect(engine.invulnerable, isTrue);

    _run(engine, const Duration(milliseconds: 150));
    expect(engine.invulnerable, isFalse);
    expect(engine.isPlaying, isTrue);
    _crash(engine);
    expect(engine.state, RunState.down);
    expect(engine.canRevive, isFalse, reason: 'one revive per run');
    engine.dispose();
  });

  test('the ramp keeps rising past 30 s up to a cap', () {
    final engine = _engine();
    (double, double) at(int seconds) {
      engine.flightTime = Duration(seconds: seconds);
      return (engine.spawnInterval, engine.speedFactor);
    }

    var (interval, speed) = at(0);
    for (final seconds in [30, 45, 60, 90, 120]) {
      final (nextInterval, nextSpeed) = at(seconds);
      expect(nextInterval, lessThan(interval), reason: 'spawn at $seconds s');
      expect(nextSpeed, greaterThan(speed), reason: 'speed at $seconds s');
      (interval, speed) = (nextInterval, nextSpeed);
    }
    expect(at(300), (interval, speed), reason: 'capped after 120 s');
    engine.dispose();
  });

  test('rocks spawned late in a run fall faster than early ones', () {
    double firstSpeedFrom(Duration start) {
      final engine = _engine(seed: 5)..start();
      engine.flightTime = start;
      while (engine.spawned == 0) {
        engine.tick(_frame);
      }
      final speed = engine.asteroids.single.speed;
      engine.dispose();
      return speed;
    }

    final early = firstSpeedFrom(Duration.zero);
    final later = firstSpeedFrom(const Duration(seconds: 90));
    expect(later, greaterThan(early * 1.5));
  });

  test('finish gives a result with the run duration', () {
    fakeAsync((async) {
      final engine = _engine()..start();
      engine.asteroids.add(_rock(x: 0.9, y: 0.99, speed: 1));
      engine.tick(_frame);
      async.elapse(const Duration(seconds: 4));
      _crash(engine);

      // Time spent down (waiting on a revive) doesn't count.
      async.elapse(const Duration(seconds: 3));
      engine.finish();
      expect(engine.isFinished, isTrue);
      expect(engine.result!.duration, const Duration(seconds: 4));
      expect(engine.result!.score, 10);
      expect(engine.result!.game, GameId.rocketLaunch);

      final time = engine.flightTime;
      engine.tick(_frame);
      expect(engine.flightTime, time);
      engine.dispose();
    });
  });
}
