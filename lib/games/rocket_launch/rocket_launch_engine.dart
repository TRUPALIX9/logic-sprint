import 'dart:math';

import '../../core/config.dart';
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

/// Rocket Launch: the rocket chases the player's finger along the bottom of
/// the field, dodging falling asteroids. Each rock that falls past scores; a
/// hit costs points. One mode for every [difficulty] (it is ignored): the
/// round starts calm and ramps to a meteor storm by the end. The screen
/// drives [tick] from a Ticker, so the simulation owns no timers.
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
  static const hitPenalty = 15;
  static const hitFlash = Duration(milliseconds: 320);

  static const _fallSpeed = 0.32;

  // Calm → storm, spanning the old easy → hard tuning (45 frames at 60 fps
  // down to a shrunken 25; speed ×1.0 up to ×2.8).
  static const _calmInterval = 0.75;
  static const _stormInterval = 0.24;
  static const _calmSpeed = 1.0;
  static const _stormSpeed = 2.8;

  // A stalled frame advances at most this much, so rocks never teleport.
  static const _maxStep = Duration(milliseconds: 50);

  double rocketX = 0.5;

  /// Where the finger is; [tick] eases [rocketX] toward it.
  double targetX = 0.5;
  final List<Asteroid> asteroids = [];
  Duration elapsed = Duration.zero;
  int spawned = 0;

  /// [elapsed] at the last hit; drives the brief coral flash.
  Duration? lastHit;
  bool _running = false;
  double _untilSpawn = 0;

  double get _seconds =>
      elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  /// 0 at the start of the round, 1 at the end.
  double get ramp => min(1, _seconds / AppConfig.roundSeconds);

  /// Seconds between spawns right now.
  double get spawnInterval =>
      _calmInterval + (_stormInterval - _calmInterval) * ramp;

  /// Fall-speed multiplier right now.
  double get speedFactor => _calmSpeed + (_stormSpeed - _calmSpeed) * ramp;

  /// Hit flash strength: 1 right after a hit, fading to 0.
  double get flash {
    final hit = lastHit;
    if (hit == null) {
      return 0;
    }
    final t = (elapsed - hit).inMicroseconds / hitFlash.inMicroseconds;
    return t >= 1 ? 0 : 1 - t;
  }

  bool get flashing => flash > 0;

  void steerTo(double x) {
    if (isFinished) {
      return;
    }
    targetX = x.clamp(minX, maxX);
  }

  /// Advances the field by [dt]. A no-op before start and after finish.
  void tick(Duration dt) {
    if (!_running || isFinished || dt <= Duration.zero) {
      return;
    }
    final step = dt > _maxStep ? _maxStep : dt;
    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    elapsed += step;

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
      if (crossed && (rock.x - rocketX).abs() < hitReach) {
        asteroids.remove(rock);
        lastHit = elapsed;
        scoreWrong(penalty: hitPenalty);
      } else if (rock.y >= 1) {
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

  @override
  void onStart() => _running = true;
}
