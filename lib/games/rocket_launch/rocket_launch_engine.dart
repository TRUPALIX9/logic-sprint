import 'dart:math';

import '../../models/game.dart';
import '../round_engine.dart';

/// One falling rock. [x] and [y] are its centre as fractions of the field;
/// [size] is its diameter in logical px, [speed] field heights per second.
class Asteroid {
  Asteroid({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    this.seed = 0,
    this.rotation = 0,
    this.spin = 0,
  });

  final double x;
  double y;
  final double size;
  final double speed;

  /// Picks the rock's outline and craters; only affects drawing.
  final int seed;

  /// Radians, turning at [spin] radians per second.
  double rotation;
  final double spin;
}

/// Rocket Launch: an endless run. The rocket chases the player's finger
/// along the bottom of the field; each rock that falls past scores and the
/// first hit sends the run down. It starts calm and ramps without end (to a
/// humane cap). [difficulty] is ignored. The screen drives [tick] from a
/// Ticker, so the simulation owns no timers.
class RocketLaunchEngine extends RoundEngine {
  RocketLaunchEngine({
    required super.difficulty,
    super.previousBest,
    super.feedback,
    super.random,
  }) : super(game: GameId.rocketLaunch) {
    _untilSpawn = spawnInterval;
  }

  static const rocketY = 0.85;
  static const minX = 0.05;
  static const maxX = 0.95;

  /// Top rocket speed, in field widths per second.
  static const steerSpeed = 1.8;

  /// A rock hits when it is within [hitReach] of the rocket horizontally
  /// while crossing the band [hitTop]..[hitBottom].
  static const hitReach = 0.12;
  static const hitTop = 0.80;
  static const hitBottom = 0.90;

  /// Invulnerability after a revive.
  static const reviveShield = Duration(milliseconds: 1500);

  /// Calm at 0 s, the old "meteor storm" by [stormAt] s, then creeping up
  /// to a cap at [capAt] s so it stays playable.
  static const stormAt = 60.0;
  static const capAt = 120.0;

  static const _fallSpeed = 0.32;

  // A stalled frame advances at most this much, so rocks never teleport.
  static const _maxStep = Duration(milliseconds: 50);

  double rocketX = 0.5;

  /// Where the finger is; [tick] eases [rocketX] toward it.
  double targetX = 0.5;
  final List<Asteroid> asteroids = [];
  int spawned = 0;

  /// Simulated flight time: the sum of [tick] steps while playing. Drives
  /// the ramp and the scenery (the base [elapsed] is the wall-clock run).
  Duration flightTime = Duration.zero;
  Duration _shieldUntil = Duration.zero;
  double _untilSpawn = 0;

  double get _seconds =>
      flightTime.inMicroseconds / Duration.microsecondsPerSecond;

  bool get invulnerable => flightTime < _shieldUntil;

  static double _ramp(double seconds, double calm, double storm, double cap) {
    if (seconds <= stormAt) {
      return calm + (storm - calm) * seconds / stormAt;
    }
    final creep = min(1.0, (seconds - stormAt) / (capAt - stormAt));
    return storm + (cap - storm) * creep;
  }

  /// Seconds between spawns right now.
  double get spawnInterval => _ramp(_seconds, 0.75, 0.24, 0.18);

  /// Fall-speed multiplier right now.
  double get speedFactor => _ramp(_seconds, 1.0, 2.8, 3.4);

  void steerTo(double x) {
    if (state == RunState.down || isFinished) {
      return;
    }
    targetX = x.clamp(minX, maxX);
  }

  /// Advances the field by [dt]. A no-op unless playing.
  void tick(Duration dt) {
    if (!isPlaying || dt <= Duration.zero) {
      return;
    }
    final step = dt > _maxStep ? _maxStep : dt;
    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    flightTime += step;

    // Ease toward the finger: fast when far, slowing as it arrives, never
    // faster than steerSpeed.
    final gap = targetX - rocketX;
    final move = min(steerSpeed, gap.abs() * 10) * seconds;
    rocketX += move >= gap.abs() ? gap : move * gap.sign;

    _untilSpawn -= seconds;
    while (_untilSpawn <= 0) {
      _spawn();
      _untilSpawn += spawnInterval;
    }

    for (final rock in [...asteroids]) {
      final from = rock.y;
      rock
        ..y += rock.speed * seconds
        ..rotation += rock.spin * seconds;
      // Swept check: did the rock cross the rocket's band this step?
      final crossed = from <= hitBottom && rock.y >= hitTop;
      if (crossed && (rock.x - rocketX).abs() < hitReach && !invulnerable) {
        // The rock stays on screen so the crash reads.
        fail();
        return;
      }
      if (rock.y >= 1) {
        asteroids.remove(rock);
        scoreCorrect();
      }
    }
    notify();
  }

  void _spawn() {
    spawned++;
    asteroids.add(
      Asteroid(
        x: minX + random.nextDouble() * (maxX - minX),
        y: -0.08,
        size: 30 + random.nextDouble() * 26,
        speed: _fallSpeed * speedFactor * (0.85 + random.nextDouble() * 0.3),
        seed: random.nextInt(1 << 30),
        rotation: random.nextDouble() * 2 * pi,
        spin: (random.nextDouble() - 0.5) * 1.2,
      ),
    );
  }

  /// Second life: an empty sky, a fresh spawn gap and a short shield.
  @override
  void onRevive() {
    asteroids.clear();
    _untilSpawn = spawnInterval;
    _shieldUntil = flightTime + reviveShield;
  }
}
