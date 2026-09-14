import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A one-shot burst of chamfer-style confetti (small rectangles), fanned
/// upward from [origin] (fractions of the box) and falling under gravity.
/// Plays once when inserted; repaints from its controller only, so the
/// widgets around it never rebuild.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.count = 64,
    this.origin = const Alignment(0, -0.75),
    this.duration = const Duration(milliseconds: 1600),
  });

  final int count;
  final Alignment origin;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final List<_Particle> _particles = _Particle.burst(
    widget.count,
    math.Random(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            _controller,
            _particles,
            widget.origin,
            widget.duration.inMilliseconds / 1000,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.width,
    required this.height,
    required this.color,
  });

  static const _colors = [LS.teal, LS.blue, LS.gold, LS.coral, LS.text];

  static List<_Particle> burst(int count, math.Random random) => [
    for (var i = 0; i < count; i++)
      _Particle(
        // Upward fan, ±65° around straight up.
        angle: -math.pi / 2 + (random.nextDouble() - 0.5) * 2.3,
        speed: 380 + random.nextDouble() * 520,
        spin: (random.nextDouble() - 0.5) * 16,
        width: 4 + random.nextDouble() * 4,
        height: 7 + random.nextDouble() * 6,
        color: _colors[i % _colors.length],
      ),
  ];

  final double angle;

  /// Launch speed in logical px per second.
  final double speed;

  /// Radians per second.
  final double spin;
  final double width;
  final double height;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.particles, this.origin, this.seconds)
    : super(repaint: progress);

  final Animation<double> progress;
  final List<_Particle> particles;
  final Alignment origin;
  final double seconds;

  static const _gravity = 1400.0;

  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) {
      return;
    }
    final start = origin.alongSize(size);
    final s = t * seconds;
    final fade = 1 - Curves.easeInQuad.transform(t);
    for (final p in particles) {
      // Air drag: horizontal travel slows down over time.
      final drift = p.speed * (1 - math.exp(-2.2 * s)) / 2.2;
      final x = start.dx + math.cos(p.angle) * drift;
      final y =
          start.dy + math.sin(p.angle) * p.speed * s + 0.5 * _gravity * s * s;
      _paint.color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * s)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          ),
          _paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.particles != particles || old.origin != origin;
}
