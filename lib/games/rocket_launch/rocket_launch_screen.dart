import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/kit.dart';
import '../round_engine.dart';
import '../round_screen.dart';
import 'rocket_launch_engine.dart';

class RocketLaunchScreen extends StatelessWidget {
  const RocketLaunchScreen({super.key, required this.difficulty});

  /// Passed through to the engine, which ignores it (one ramping mode).
  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return RoundScreen<RocketLaunchEngine>(
      game: GameId.rocketLaunch,
      difficulty: difficulty,
      createEngine: (feedback, best) => RocketLaunchEngine(
        difficulty: difficulty,
        previousBest: best,
        feedback: feedback,
      ),
      builder: (context, engine) => _RocketLaunchBody(engine),
    );
  }
}

/// Edge-to-edge space field. A Ticker drives the engine (RoundScreen
/// rebuilds on every notify); a finger held anywhere on it steers.
class _RocketLaunchBody extends StatefulWidget {
  const _RocketLaunchBody(this.engine);

  final RocketLaunchEngine engine;

  @override
  State<_RocketLaunchBody> createState() => _RocketLaunchBodyState();
}

class _RocketLaunchBodyState extends State<_RocketLaunchBody>
    with SingleTickerProviderStateMixin {
  static const _rocketSize = Size(56, 92);
  static const _flashTime = Duration(milliseconds: 220);

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Wall-clock time from the ticker; animates the flame and the hit flash
  /// (the engine is frozen while the run is down).
  Duration _now = Duration.zero;

  /// Ticker time when the run went down.
  Duration? _hitAt;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration now) {
    final engine = widget.engine;
    if (engine.isFinished) {
      _ticker.stop();
      return;
    }
    final dt = now - _last;
    _last = now;
    _now = now;
    if (engine.isPlaying) {
      _hitAt = null;
      engine.tick(dt);
    } else if (engine.state == RunState.down) {
      _hitAt ??= now;
      if (now - _hitAt! <= _flashTime) {
        setState(() {});
      }
    }
  }

  /// Hit flash strength: 1 as the run goes down, fading to 0.
  double get _flash {
    if (widget.engine.state != RunState.down) {
      return 0;
    }
    final hit = _hitAt;
    if (hit == null) {
      return 1;
    }
    final t = (_now - hit).inMicroseconds / _flashTime.inMicroseconds;
    return t >= 1 ? 0 : 1 - t;
  }

  void _steer(Offset local, double width) {
    if (!_touched) {
      setState(() => _touched = true);
    }
    widget.engine.steerTo(local.dx / width);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final flash = _flash;
        // Small horizontal shake that dies out with the flash.
        final shake = sin(_now.inMilliseconds / 16) * 5 * flash;
        // Lean into the turn while chasing the finger.
        final lean = ((engine.targetX - engine.rocketX) * 2).clamp(-0.3, 0.3);
        // Blink while the revive shield is up.
        final blink = (engine.flightTime.inMilliseconds ~/ 120).isEven;
        final rocketOpacity = engine.invulnerable ? (blink ? 0.3 : 0.85) : 1.0;
        return Semantics(
          label: 'Touch and drag to steer',
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _steer(e.localPosition, w),
            onPointerMove: (e) => _steer(e.localPosition, w),
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(shake, 0),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(painter: _NebulaPainter()),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _StarPainter(engine.flightTime),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AsteroidPainter(engine.asteroids),
                            ),
                          ),
                          Positioned(
                            left: engine.rocketX * w - _rocketSize.width / 2,
                            top:
                                RocketLaunchEngine.rocketY * h -
                                _rocketSize.height / 2,
                            child: Opacity(
                              opacity: rocketOpacity,
                              child: Transform.rotate(
                                angle: lean,
                                child: CustomPaint(
                                  size: _rocketSize,
                                  painter: _RocketPainter(_now),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (flash > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: LS.coral.withValues(alpha: 0.24 * flash),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _touched ? 0 : 1,
                        duration: const Duration(milliseconds: 600),
                        child: Center(
                          child: MonoLabel(
                            'Touch and drag to steer',
                            color: LS.muted.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Deep space: faint nebula glows and a distant planet. Static.
class _NebulaPainter extends CustomPainter {
  const _NebulaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = LS.bg);

    void glow(Offset center, double radius, Color color, double alpha) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        all,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    glow(Offset(w * 0.15, h * 0.3), w * 0.9, LS.violet, 0.10);
    glow(Offset(w * 0.9, h * 0.62), w * 0.8, LS.blue, 0.09);
    glow(Offset(w * 0.45, h * 1.02), w * 0.7, LS.teal, 0.06);

    // Planet peeking in from the top-right corner, lit from the top-left.
    final center = Offset(w * 1.02, h * 0.09);
    final radius = w * 0.3;
    final disc = Rect.fromCircle(center: center, radius: radius);
    canvas
      ..drawCircle(
        center,
        radius + 2,
        Paint()
          ..color = LS.aqua.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.55, -0.45),
            colors: [LS.line, LS.surface2, LS.well],
            stops: [0, 0.45, 1],
          ).createShader(disc),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = LS.aqua.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_NebulaPainter oldDelegate) => false;
}

typedef _Star = ({double x, double y, double size, Color color});

/// Far, mid and near star layers: (drift in field heights per second, stars).
final List<(double, List<_Star>)> _starLayers = () {
  final r = Random(42);
  List<_Star> make(int count, double size, double alpha, {bool tint = false}) {
    return [
      for (var i = 0; i < count; i++)
        (
          x: r.nextDouble(),
          y: r.nextDouble(),
          size: size * (0.7 + r.nextDouble() * 0.6),
          color: (tint && i % 4 == 0 ? LS.teal : LS.text).withValues(
            alpha: alpha * (0.6 + r.nextDouble() * 0.4),
          ),
        ),
    ];
  }

  return [
    (0.012, make(70, 1.0, 0.3)),
    (0.035, make(36, 1.5, 0.5)),
    (0.09, make(14, 2.2, 0.8, tint: true)),
  ];
}();

/// Parallax stars drifting down; nearer layers move faster.
class _StarPainter extends CustomPainter {
  _StarPainter(this.time);

  final Duration time;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = time.inMicroseconds / Duration.microsecondsPerSecond;
    final paint = Paint();
    for (final (speed, stars) in _starLayers) {
      final drift = seconds * speed;
      for (final star in stars) {
        final y = (star.y + drift) % 1;
        paint.color = star.color;
        canvas.drawCircle(
          Offset(star.x * size.width, y * size.height),
          star.size / 2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.time != time;
}

/// Teal shade: [t] 0 is LS.teal, 1 is black, negative mixes toward LS.text.
Color _teal(double t) =>
    t < 0 ? Color.lerp(LS.teal, LS.text, -t)! : Color.lerp(LS.teal, LS.bg, t)!;

/// Irregular, shaded teal rocks. Each outline and its craters come from the
/// asteroid's seed; light always falls from the top-left, whatever the spin.
class _AsteroidPainter extends CustomPainter {
  _AsteroidPainter(this.asteroids);

  final List<Asteroid> asteroids;

  static final _lit = _teal(0.45);
  static final _body = _teal(0.72);
  static final _shadow = _teal(0.9);
  static final _rim = _teal(-0.3);
  static final _pit = _teal(0.93);
  static final _lip = _teal(0.5);

  @override
  void paint(Canvas canvas, Size size) {
    for (final rock in asteroids) {
      _paintRock(
        canvas,
        rock,
        Offset(rock.x * size.width, rock.y * size.height),
      );
    }
  }

  void _paintRock(Canvas canvas, Asteroid rock, Offset center) {
    final r = rock.size / 2;
    final shape = Random(rock.seed);
    Offset at(double angle, double distance) =>
        center +
        Offset(cos(angle + rock.rotation), sin(angle + rock.rotation)) *
            distance;

    final corners = 7 + shape.nextInt(5);
    final outline = Path()
      ..addPolygon([
        for (var i = 0; i < corners; i++)
          at(
            (i + shape.nextDouble() * 0.5) / corners * 2 * pi,
            r * (0.75 + shape.nextDouble() * 0.25),
          ),
      ], true);
    final bounds = Rect.fromCircle(center: center, radius: r);

    canvas
      ..drawPath(
        outline,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.45),
            radius: 0.9,
            colors: [_lit, _body, _shadow],
            stops: const [0, 0.5, 1],
          ).createShader(bounds),
      )
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_rim.withValues(alpha: 0.7), _rim.withValues(alpha: 0)],
            stops: const [0.1, 0.65],
          ).createShader(bounds),
      );

    final pit = Paint()..color = _pit.withValues(alpha: 0.85);
    final lip = Paint()
      ..color = _lip
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final craters = 2 + shape.nextInt(3);
    for (var i = 0; i < craters; i++) {
      final c = at(shape.nextDouble() * 2 * pi, r * shape.nextDouble() * 0.45);
      final radius = r * (0.1 + shape.nextDouble() * 0.12);
      // The lower-right inner wall catches the top-left light.
      canvas
        ..drawCircle(c, radius, pit)
        ..drawArc(
          Rect.fromCircle(center: c, radius: radius),
          -pi / 4,
          pi,
          false,
          lip,
        );
    }
  }

  // The engine mutates rocks in place, so always repaint.
  @override
  bool shouldRepaint(_AsteroidPainter oldDelegate) => true;
}

/// The mockup's 56×92 rocket with a flickering exhaust flame.
class _RocketPainter extends CustomPainter {
  _RocketPainter(this.now);

  final Duration now;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Path()
      ..moveTo(28, 2)
      ..cubicTo(38, 10, 42, 22, 42, 36)
      ..lineTo(42, 54)
      ..lineTo(14, 54)
      ..lineTo(14, 36)
      ..cubicTo(14, 22, 18, 10, 28, 2)
      ..close();
    final fins = Path()
      ..addPolygon(const [
        Offset(14, 40),
        Offset(4, 54),
        Offset(4, 62),
        Offset(14, 56),
      ], true)
      ..addPolygon(const [
        Offset(42, 40),
        Offset(52, 54),
        Offset(52, 62),
        Offset(42, 56),
      ], true);
    final t = now.inMilliseconds.toDouble();
    final flicker = 1 + 0.12 * sin(t / 40) + 0.06 * sin(t / 17);
    Path flame(double half, double length) => Path()
      ..addPolygon([
        Offset(28 - half, 66),
        Offset(28 + half, 66),
        Offset(28, 66 + length * flicker),
      ], true);

    canvas
      ..drawPath(
        body,
        Paint()
          ..color = LS.blue.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      )
      ..drawPath(
        flame(8, 26),
        Paint()
          ..color = LS.blue.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(flame(6, 24), Paint()..color = LS.blue)
      ..drawPath(flame(3, 14), Paint()..color = LS.teal)
      ..drawPath(flame(1.2, 6), Paint()..color = LS.text)
      ..drawPath(fins, Paint()..color = LS.blue)
      ..drawPath(body, Paint()..color = LS.text)
      ..drawPath(
        Path()..addPolygon(const [
          Offset(20, 58),
          Offset(36, 58),
          Offset(33, 64),
          Offset(23, 64),
        ], true),
        Paint()..color = LS.dim,
      )
      ..drawCircle(const Offset(28, 28), 6, Paint()..color = LS.bg)
      ..drawCircle(
        const Offset(28, 28),
        6,
        Paint()
          ..color = LS.teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
  }

  @override
  bool shouldRepaint(_RocketPainter oldDelegate) => oldDelegate.now != now;
}
