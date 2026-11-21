import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../games/rocket_launch/rocket_look.dart';
import '../models/game.dart';
import '../services/leaderboard.dart';
import '../services/network.dart';
import '../ui/brand.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'shell.dart';

/// Launch into the games (design/plans/upgrades_plan.html, G).
///
/// The logo stays exactly where the native launch screen drew it (centred,
/// same size), so there's no jump. The Rocket Launch ship launches out of it
/// and climbs, paying out a line of 0s and 1s, then hovers; LOGICSPRINT
/// slides in under the logo. One circuit line per game runs out to a node in
/// that game's colour, a pulse travels along it, and the node lights up when
/// it arrives. Faint stars twinkle behind.
///
/// The bar is real: it fills as start-up work finishes (queued runs sent,
/// today's boards and Sprint Score fetched), so Ranks opens warm. The splash
/// leaves once both the intro and the loading are done, and never later than
/// [maxShown]. Reduce motion shows the finished frame with every node lit.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const maxShown = Duration(milliseconds: 2600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// The fly-in: launch, wordmark, lines and nodes (0 → 1 over 1.5 s).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Ambient time for the hover, sway, twinkle and pulses.
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _now = elapsed),
  );
  Duration _now = Duration.zero;

  double _progress = 0;
  String _step = 'Starting';
  bool _left = false;
  Timer? _cap;

  @override
  void initState() {
    super.initState();
    _cap = Timer(SplashScreen.maxShown, _leave);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _ticker.start();
    }
    unawaited(_load());
  }

  /// Real start-up work, each step capped so a slow network can't hold the
  /// splash past [SplashScreen.maxShown].
  Future<void> _load() async {
    final leaderboard = context.read<Leaderboard>();
    final online = context.read<Network>().online.value;

    Future<void> step(
      String label,
      double to,
      Future<void> Function() work,
    ) async {
      if (!mounted) {
        return;
      }
      setState(() => _step = label);
      try {
        await work().timeout(const Duration(milliseconds: 1200));
      } on Object {
        // Offline or slow: the app copes later; the bar still moves on.
      }
      if (mounted) {
        setState(() => _progress = to);
      }
    }

    await step('Loading your bests', 0.35, () async {});
    if (online) {
      await step('Sending your runs', 0.6, leaderboard.syncPending);
      await step(
        "Fetching today's boards",
        1,
        () => leaderboard.load(GameId.rocketLaunch, GameId.rampDifficulty),
      );
    } else {
      await step('Offline · saved scores', 1, () async {});
    }
    if (!mounted) {
      return;
    }
    setState(() => _step = 'Ready');
    // Let the intro finish (it's already done with reduce motion).
    if (_intro.isAnimating) {
      await _intro.forward().orCancel.catchError((Object _) {});
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _leave();
  }

  void _leave() {
    if (_left || !mounted) {
      return;
    }
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, _, _) => const Shell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _cap?.cancel();
    _ticker.dispose();
    _intro.dispose();
    super.dispose();
  }

  /// How far node [i]'s line is lit (0–1), staggered after the wordmark
  /// lands.
  static double litAt(double t, int i) =>
      ((t - 0.35 - i * 0.05) / 0.25).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LS.bg,
      body: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final t = _intro.value;
          return LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              // The native launch screen centres the logo in a 120 pt box.
              final centre = Offset(size.width / 2, size.height / 2);
              final nodes = _nodes(size);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SplashPainter(
                        centre: centre,
                        nodes: nodes,
                        intro: t,
                        now: _now,
                      ),
                    ),
                  ),
                  for (final (i, node) in nodes.indexed)
                    Positioned(
                      left: node.at.dx - 24,
                      top: node.at.dy - 24,
                      child: _GameNode(game: node.game, lit: litAt(t, i)),
                    ),
                  ..._towed(size, centre, t),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 56,
                    child: _LoadingBar(progress: _progress, step: _step),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Six nodes, two per row on each side, kept clear of the centre.
  static List<_Node> _nodes(Size size) {
    final w = size.width, h = size.height;
    return [
      _Node(GameId.rocketLaunch, Offset(w * 0.17, h * 0.2)),
      _Node(GameId.memoryLane, Offset(w * 0.83, h * 0.2)),
      _Node(GameId.quickMath, Offset(w * 0.12, h * 0.67)),
      _Node(GameId.guessColor, Offset(w * 0.88, h * 0.67)),
      _Node(GameId.angleSense, Offset(w * 0.3, h * 0.8)),
      _Node(GameId.lineSplit, Offset(w * 0.7, h * 0.8)),
    ];
  }

  /// Logo size whose mark matches the native launch image (120 pt box).
  static const _logo = 92.0;

  /// The logo (fixed, matching the launch screen), the rocket launching out
  /// of it on a line of bits, and the wordmark sliding in underneath.
  List<Widget> _towed(Size size, Offset centre, double t) {
    final ms = _now.inMilliseconds;
    // Climb from the logo to its hover spot by 55% of the intro.
    final climb = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
    final logoTop = centre.dy - _logo / 2;
    final hoverY = logoTop - 160 + 5 * sin(ms / 520);
    final rocketY = logoTop + 10 + (hoverY - logoTop - 10) * climb;
    final sway = 3 * sin(ms / 700) * climb;
    final ropeTop = rocketY + 58;
    final ropeLength = max(0.0, logoTop + 8 - ropeTop);
    final bits = (ropeLength / 13).floor();
    final flow = ms ~/ 140;
    final words = Curves.easeOut.transform(((t - 0.2) / 0.3).clamp(0.0, 1.0));
    return [
      for (var i = 0; i < bits; i++)
        Positioned(
          left: centre.dx - 3 + sway * (1 - i / max(1, bits)),
          top: ropeTop + i * 13,
          child: Text(
            (i + flow).isEven ? '1' : '0',
            style: LSText.mono(
              10,
              color: LS.teal.withValues(
                alpha: 0.3 + 0.6 * (1 - i / max(1, bits)),
              ),
              weight: FontWeight.w700,
            ).copyWith(height: 1.3),
          ),
        ),
      Positioned(
        left: centre.dx - 18 + sway,
        top: rocketY,
        child: Opacity(
          opacity: (t / 0.08).clamp(0.0, 1.0),
          child: SizedBox(
            width: 36,
            height: 60,
            child: CustomPaint(
              painter: ShipPainter(ShipKind.rocket, SpaceTheme.at(0), _now),
            ),
          ),
        ),
      ),
      Positioned(
        left: centre.dx - _logo / 2,
        top: logoTop,
        child: const LogoMark(size: _logo),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: logoTop + _logo + 8 + 16 * (1 - words),
        child: Opacity(
          opacity: words,
          child: const Column(
            children: [
              Wordmark(size: 40),
              SizedBox(height: 6),
              MonoLabel('Brain games', size: 12, color: LS.aqua),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Node {
  const _Node(this.game, this.at);
  final GameId game;
  final Offset at;
}

/// A game's icon in a chamfered tile: dim until its line reaches it.
class _GameNode extends StatelessWidget {
  const _GameNode({required this.game, required this.lit});

  final GameId game;
  final double lit;

  @override
  Widget build(BuildContext context) {
    final on = lit >= 1;
    final accent = game.accent;
    return AnimatedScale(
      scale: on ? 1 : 0.9,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Container(
        width: 48,
        height: 48,
        decoration: ShapeDecoration(
          shape: chamfer(Cut.sm, border: on ? accent : LS.line),
          color: on ? Color.lerp(LS.surface, accent, 0.18) : LS.surface,
          shadows: on
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Icon(
          game.icon,
          size: 24,
          color: on ? accent : accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress, required this.step});

  final double progress;
  final String step;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 180,
          height: 4,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            builder: (context, value, _) =>
                CustomPaint(painter: _BarPainter(value)),
          ),
        ),
        const SizedBox(height: 10),
        MonoLabel(step, size: 10, color: LS.dim),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = LS.surface2,
    );
    if (value <= 0) {
      return;
    }
    final fill = Rect.fromLTWH(0, 0, size.width * value, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, r),
      Paint()..shader = LS.brandGradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.value != value;
}

/// Stars, then a circuit line from the centre to each node: a dim track, a
/// lit part growing toward the node, and a pulse that keeps travelling.
class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.centre,
    required this.nodes,
    required this.intro,
    required this.now,
  });

  final Offset centre;
  final List<_Node> nodes;
  final double intro;
  final Duration now;

  static final _stars = () {
    final r = Random(7);
    return [
      for (var i = 0; i < 70; i++)
        (
          x: r.nextDouble(),
          y: r.nextDouble(),
          s: 0.6 + r.nextDouble() * 1.2,
          p: r.nextDouble() * 6,
        ),
    ];
  }();

  /// Centre → node as a circuit trace: out horizontally, a 45° bend, then
  /// vertically to the node's edge.
  Path _trace(Offset to) {
    final start = Offset(
      centre.dx + (to.dx < centre.dx ? -60 : 60),
      centre.dy + (to.dy < centre.dy ? -20 : 80),
    );
    final dy = to.dy - start.dy;
    final bend = min(28.0, (to.dx - start.dx).abs() / 2);
    final mid = Offset(to.dx - (to.dx > start.dx ? bend : -bend), start.dy);
    final turn = Offset(to.dx, start.dy + dy.sign * bend);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(turn.dx, turn.dy)
      ..lineTo(to.dx, to.dy - dy.sign * 26);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final secs = now.inMilliseconds / 1000;
    for (final s in _stars) {
      final twinkle = 0.25 + 0.25 * sin(secs * 1.3 + s.p);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.s,
        Paint()..color = LS.text.withValues(alpha: twinkle),
      );
    }

    for (final (i, node) in nodes.indexed) {
      final path = _trace(node.at);
      final accent = node.game.accent;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: 0.18),
      );
      final lit = _SplashScreenState.litAt(intro, i);
      if (lit <= 0) {
        continue;
      }
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * lit),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: 0.8),
      );
      // The pulse: at the head while growing, then looping centre → node.
      final at = lit < 1 ? lit : (secs * 0.55 + i * 0.17) % 1;
      final tangent = metric.getTangentForOffset(metric.length * at);
      if (tangent != null) {
        canvas
          ..drawCircle(
            tangent.position,
            6,
            Paint()..color = accent.withValues(alpha: 0.25),
          )
          ..drawCircle(tangent.position, 2.6, Paint()..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) =>
      old.intro != intro || old.now != now;
}
