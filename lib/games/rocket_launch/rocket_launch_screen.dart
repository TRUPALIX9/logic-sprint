import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../ui/kit.dart';
import '../round_engine.dart';
import '../round_screen.dart';
import 'rocket_launch_engine.dart';
import 'rocket_look.dart';
import 'space_scenery.dart';
import 'whispers.dart';

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
  static const _rocketSize = ShipPainter.size;
  static const _flashTime = Duration(milliseconds: 220);

  /// A theme change rolls through the scene in order: the ship, then the
  /// rocks, then space. Measured in flight time, so it holds while paused.
  static const _shipFade = (0, 700);
  static const _rockFade = (500, 1400);
  static const _spaceFade = (1200, 2600);

  /// How long "Level N" shows after a change.
  static const _levelBanner = 2200;

  /// The easter egg (see whispers.dart): a random unseen line drifts through
  /// space from [_whisperFrom] to [_whisperTo] ms after each colour change.
  static const _whisperFrom = 400;
  static const _whisperTo = 3800;

  late final ShipKind _ship = context.read<AppState>().rocketShip;

  /// The easter-egg line for the current level (picked at each change).
  String? _whisper;

  /// The level the scene is heading to, the look it started from, and the
  /// flight time the change began.
  int _level = 0;
  SpaceTheme _from = SpaceTheme.at(0);
  Duration? _changedAt;

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

  /// Milliseconds of flight since the last theme change (null: none yet).
  int? get _sinceChange {
    final at = _changedAt;
    return at == null ? null : (widget.engine.flightTime - at).inMilliseconds;
  }

  /// The look right now, mid-change or settled.
  SpaceTheme _theme() {
    final engine = widget.engine;
    if (engine.themeLevel != _level) {
      // Start from wherever the last change had got to.
      _from = _blended();
      _level = engine.themeLevel;
      _changedAt = engine.flightTime;
      _pickWhisper();
    }
    return _blended();
  }

  /// A random line this player hasn't seen yet; remembered across runs.
  void _pickWhisper() {
    final storage = context.read<AppState>().storage;
    final (line, seen) = nextWhisper(storage.whispersSeen, Random());
    _whisper = line;
    storage.setWhispersSeen(seen);
  }

  /// [_from] rolling toward the current level's theme.
  SpaceTheme _blended() {
    final to = SpaceTheme.at(_level);
    final since = _sinceChange;
    if (since == null) {
      return to;
    }
    double stage((int, int) window) => Curves.easeInOut.transform(
      ((since - window.$1) / (window.$2 - window.$1)).clamp(0.0, 1.0),
    );
    return _from.blend(
      to,
      ship: stage(_shipFade),
      rock: stage(_rockFade),
      space: stage(_spaceFade),
    );
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
        final theme = _theme();
        final since = _sinceChange;
        // Fades in, holds, fades out.
        // 0 → 1 → 0 across its window, and how far it has drifted.
        final whisperT = since == null
            ? 1.0
            : (since - _whisperFrom) / (_whisperTo - _whisperFrom);
        final whisper = whisperT <= 0 || whisperT >= 1
            ? 0.0
            : sin(whisperT * pi);
        final banner = since == null || since >= _levelBanner
            ? 0.0
            : min(1.0, min(since, _levelBanner - since) / 300);
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
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _NebulaPainter(theme),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SceneryPainter(engine.flightTime, theme),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _StarPainter(engine.flightTime),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AsteroidPainter(
                                engine.asteroids,
                                theme.rock,
                              ),
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
                                  painter: ShipPainter(_ship, theme, _now),
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
                  if (whisper > 0 && _whisper != null)
                    Positioned(
                      left: w * (0.1 + 0.22 * (_level % 3)),
                      top: h * (0.46 - 0.06 * whisperT),
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.5 * whisper,
                          child: Text(
                            _whisper!,
                            style: LSText.mono(9, color: theme.hull),
                          ),
                        ),
                      ),
                    ),
                  if (banner > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 28,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: banner,
                          child: Column(
                            children: [
                              DisplayText(
                                'Level ${_level + 1}',
                                size: 30,
                                color: theme.hull,
                              ),
                              const SizedBox(height: 4),
                              MonoLabel(
                                '${_level * RocketLaunchEngine.themeEvery} pts',
                                color: theme.flame,
                              ),
                            ],
                          ),
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

/// Deep space in [theme]'s colours: the fill and faint nebula glows.
class _NebulaPainter extends CustomPainter {
  const _NebulaPainter(this.theme);

  final SpaceTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = theme.space);

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

    glow(Offset(w * 0.15, h * 0.3), w * 0.9, theme.glows[0], 0.10);
    glow(Offset(w * 0.9, h * 0.62), w * 0.8, theme.glows[1], 0.09);
    glow(Offset(w * 0.45, h * 1.02), w * 0.7, theme.glows[2], 0.06);
  }

  @override
  bool shouldRepaint(_NebulaPainter oldDelegate) => oldDelegate.theme != theme;
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

/// Irregular rocks shaded from [tint]. Each outline and its craters come
/// from the asteroid's seed; light always falls from the top-left, whatever
/// the spin.
class _AsteroidPainter extends CustomPainter {
  _AsteroidPainter(this.asteroids, this.tint)
    : _lit = _shade(tint, -0.25),
      _body = _shade(tint, 0.2),
      _shadow = _shade(tint, 0.55),
      _rim = _shade(tint, -0.6),
      _pit = _shade(tint, 0.6),
      _lip = _shade(tint, 0.05);

  final List<Asteroid> asteroids;
  final Color tint;
  final Color _lit, _body, _shadow, _rim, _pit, _lip;

  /// [t] 0 is [tint], 1 is black, negative mixes toward LS.text.
  static Color _shade(Color tint, double t) =>
      t < 0 ? Color.lerp(tint, LS.text, -t)! : Color.lerp(tint, LS.bg, t)!;

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
        // A full light edge: the silhouette reads on any background.
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _rim.withValues(alpha: 0.55),
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
