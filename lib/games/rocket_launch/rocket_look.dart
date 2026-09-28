import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// What the player flies. Every ship fits the same 56×92 box and the same
/// hit reach, so the choice is purely cosmetic.
enum ShipKind {
  rocket('Rocket'),
  ufo('UFO'),
  spaceship('Spaceship'),
  missile('Missile');

  const ShipKind(this.label);

  final String label;

  static ShipKind parse(String? name) => ShipKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => ShipKind.rocket,
  );
}

/// One colour scheme for the field. Rocket Launch moves to the next one
/// every [RocketLaunchEngine.themeEvery] points and wraps around.
@immutable
class SpaceTheme {
  const SpaceTheme({
    required this.hull,
    required this.trim,
    required this.flame,
    required this.rock,
    required this.space,
    required this.glows,
    required this.planet,
  });

  /// Ship body, fins / details, and exhaust.
  final Color hull;
  final Color trim;
  final Color flame;

  /// Base tint the rocks are shaded from: a hue far from [space] and the
  /// glows, so rocks never blend into the background.
  final Color rock;

  /// Background fill, the three nebula glows, and the planet's rim.
  final Color space;
  final List<Color> glows;
  final Color planet;

  static const all = [
    // Deep teal: the original look.
    SpaceTheme(
      hull: LS.text,
      trim: LS.blue,
      flame: LS.teal,
      rock: Color(0xFFD9A066),
      space: LS.bg,
      glows: [LS.violet, LS.blue, LS.teal],
      planet: LS.aqua,
    ),
    // Deep ocean: cyan-teal depths, coral rocks.
    SpaceTheme(
      hull: Color(0xFFF0FEFF),
      trim: Color(0xFF22D3C5),
      flame: Color(0xFF9AF7FF),
      rock: Color(0xFFFF7F66),
      space: Color(0xFF021A20),
      glows: [Color(0xFF06B6D4), Color(0xFF14B8A6), Color(0xFF38BDF8)],
      planet: Color(0xFF67E8F9),
    ),
    // Toxic.
    SpaceTheme(
      hull: Color(0xFFEFFFE6),
      trim: Color(0xFF3DDC84),
      flame: Color(0xFFB7F34A),
      rock: Color(0xFFD08CF0),
      space: Color(0xFF06120A),
      glows: [Color(0xFF1FAA59), Color(0xFF9BE15D), Color(0xFF00C2A8)],
      planet: Color(0xFFA6F07A),
    ),
    // Nebula pink.
    SpaceTheme(
      hull: Color(0xFFFFEAF7),
      trim: Color(0xFFFF4FB8),
      flame: Color(0xFFC77DFF),
      rock: Color(0xFFF2C14E),
      space: Color(0xFF110716),
      glows: [Color(0xFFFF4FB8), Color(0xFF8B5CF6), Color(0xFFFF8FD8)],
      planet: Color(0xFFF0A6FF),
    ),
    // Ice.
    SpaceTheme(
      hull: Color(0xFFF2FBFF),
      trim: Color(0xFF6FD3FF),
      flame: Color(0xFFBDF0FF),
      rock: Color(0xFFF08A4B),
      space: Color(0xFF050B16),
      glows: [Color(0xFF3B82F6), Color(0xFF93C5FD), Color(0xFF22D3EE)],
      planet: Color(0xFFCFEFFF),
    ),
  ];

  static SpaceTheme at(int level) => all[level % all.length];

  /// Per part: [ship] blends the ship colours, [rock] the rocks and [space]
  /// the background, each 0 (this) to 1 ([other]).
  SpaceTheme blend(
    SpaceTheme other, {
    required double ship,
    required double rock,
    required double space,
  }) {
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    return SpaceTheme(
      hull: mix(hull, other.hull, ship),
      trim: mix(trim, other.trim, ship),
      flame: mix(flame, other.flame, ship),
      rock: mix(this.rock, other.rock, rock),
      space: mix(this.space, other.space, space),
      glows: [
        for (var i = 0; i < glows.length; i++)
          mix(glows[i], other.glows[i], space),
      ],
      planet: mix(planet, other.planet, space),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpaceTheme &&
      other.hull == hull &&
      other.trim == trim &&
      other.flame == flame &&
      other.rock == rock &&
      other.space == space &&
      other.planet == planet &&
      other.glows[0] == glows[0] &&
      other.glows[1] == glows[1] &&
      other.glows[2] == glows[2];

  @override
  int get hashCode => Object.hash(
    hull,
    trim,
    flame,
    rock,
    space,
    planet,
    Object.hashAll(glows),
  );
}

/// Draws a [ShipKind] in a 56×92 box (nose up), animated by [now]. Each ship
/// moves its own way: the rocket throws sparks, the UFO hovers and wobbles,
/// the spaceship pulses its twin engines and blinks its wing lights, and the
/// missile spins with a smoke trail.
class ShipPainter extends CustomPainter {
  ShipPainter(this.kind, this.theme, this.now);

  static const size = Size(56, 92);

  final ShipKind kind;
  final SpaceTheme theme;
  final Duration now;

  @override
  void paint(Canvas canvas, Size box) {
    canvas.save();
    // Scale the 56×92 drawing into whatever box we're given (e.g. previews).
    final scale = min(box.width / size.width, box.height / size.height);
    canvas
      ..translate(
        (box.width - size.width * scale) / 2,
        (box.height - size.height * scale) / 2,
      )
      ..scale(scale);
    switch (kind) {
      case ShipKind.rocket:
        _rocket(canvas);
      case ShipKind.ufo:
        // Hover: a slow bob and a gentle wobble around the saucer.
        final t = _t;
        canvas
          ..translate(28, 48 + 3 * sin(t / 320))
          ..rotate(0.07 * sin(t / 540))
          ..translate(-28, -48);
        _ufo(canvas);
      case ShipKind.spaceship:
        _spaceship(canvas);
      case ShipKind.missile:
        _missile(canvas);
    }
    canvas.restore();
  }

  double get _t => now.inMilliseconds.toDouble();

  double get _flicker {
    final t = _t;
    return 1 + 0.12 * sin(t / 40) + 0.06 * sin(t / 17);
  }

  /// Loops 0 → 1 every [ms] milliseconds, offset by [phase] (0..1).
  double _cycle(double ms, [double phase = 0]) => (_t / ms + phase) % 1;

  /// Layered exhaust pointing down from ([x], [top]); [pulse] scales it.
  void _flame(
    Canvas canvas,
    double x,
    double top,
    double half,
    double length, {
    double pulse = 1,
  }) {
    length *= pulse;
    Path cone(double w, double l) => Path()
      ..addPolygon([
        Offset(x - w, top),
        Offset(x + w, top),
        Offset(x, top + l * _flicker),
      ], true);
    canvas
      ..drawPath(
        cone(half + 2, length + 2),
        Paint()
          ..color = theme.trim.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(cone(half, length), Paint()..color = theme.trim)
      ..drawPath(cone(half / 2, length * 0.58), Paint()..color = theme.flame)
      ..drawPath(cone(half / 5, length / 4), Paint()..color = LS.text);
  }

  void _glow(Canvas canvas, Path path) => canvas.drawPath(
    path,
    Paint()
      ..color = theme.trim.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
  );

  void _window(Canvas canvas, Offset center, double radius) => canvas
    ..drawCircle(center, radius, Paint()..color = theme.space)
    ..drawCircle(
      center,
      radius,
      Paint()
        ..color = theme.flame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

  void _rocket(Canvas canvas) {
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
    _glow(canvas, body);
    _flame(canvas, 28, 66, 6, 24);
    // Sparks thrown off the exhaust, drifting out and fading.
    for (var i = 0; i < 6; i++) {
      final p = _cycle(520, i / 6);
      final side = (i.isEven ? 1 : -1) * (2 + i % 3 * 2.5);
      canvas.drawCircle(
        Offset(28 + side * p * 2.2, 80 + p * 16),
        1.6 * (1 - p) + 0.4,
        Paint()..color = theme.flame.withValues(alpha: 1 - p),
      );
    }
    canvas
      ..drawPath(fins, Paint()..color = theme.trim)
      ..drawPath(body, Paint()..color = theme.hull)
      ..drawPath(
        Path()..addPolygon(const [
          Offset(20, 58),
          Offset(36, 58),
          Offset(33, 64),
          Offset(23, 64),
        ], true),
        Paint()..color = LS.dim,
      );
    _window(canvas, const Offset(28, 28), 6);
  }

  void _ufo(Canvas canvas) {
    const center = Offset(28, 48);
    final saucer = Path()
      ..addOval(Rect.fromCenter(center: center, width: 54, height: 18));
    final dome = Path()
      ..addArc(
        Rect.fromCenter(center: const Offset(28, 44), width: 26, height: 30),
        pi,
        pi,
      )
      ..close();
    // Tractor beam instead of a flame.
    final beam = Path()
      ..addPolygon([
        const Offset(20, 55),
        const Offset(36, 55),
        Offset(42, 55 + 30 * _flicker),
        Offset(14, 55 + 30 * _flicker),
      ], true);
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.flame.withValues(alpha: 0.35 + 0.25 * sin(_t / 180).abs()),
            theme.flame.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTWH(14, 55, 28, 34)),
    );
    _glow(canvas, saucer);
    canvas
      ..drawPath(dome, Paint()..color = theme.trim.withValues(alpha: 0.55))
      ..drawPath(
        dome,
        Paint()
          ..color = theme.hull.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawPath(saucer, Paint()..color = theme.hull)
      ..drawOval(
        Rect.fromCenter(center: const Offset(28, 51), width: 40, height: 7),
        Paint()..color = theme.trim,
      );
    // Running lights chase around the rim.
    final step = now.inMilliseconds ~/ 150;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(10 + i * 9, 48),
        2,
        Paint()..color = (i + step).isEven ? theme.flame : LS.dim,
      );
    }
  }

  void _spaceship(Canvas canvas) {
    final hull = Path()
      ..addPolygon(const [
        Offset(28, 4),
        Offset(36, 30),
        Offset(54, 54),
        Offset(54, 62),
        Offset(36, 58),
        Offset(28, 62),
        Offset(20, 58),
        Offset(2, 62),
        Offset(2, 54),
        Offset(20, 30),
      ], true);
    final stripes = Path()
      ..addPolygon(const [
        Offset(36, 40),
        Offset(50, 56),
        Offset(40, 56),
        Offset(34, 48),
      ], true)
      ..addPolygon(const [
        Offset(20, 40),
        Offset(6, 56),
        Offset(16, 56),
        Offset(22, 48),
      ], true);
    _glow(canvas, hull);
    // The twin engines pulse out of step.
    final beat = sin(_t / 110);
    _flame(canvas, 18, 60, 4, 20, pulse: 1 + 0.22 * beat);
    _flame(canvas, 38, 60, 4, 20, pulse: 1 - 0.22 * beat);
    canvas
      ..drawPath(hull, Paint()..color = theme.hull)
      ..drawPath(stripes, Paint()..color = theme.trim);
    // Wing-tip navigation lights: red port, green starboard, blinking in turn.
    final port = _cycle(900) < 0.5;
    for (final (x, color, on) in [
      (4.0, const Color(0xFFFF4D5E), port),
      (52.0, const Color(0xFF3DDC84), !port),
    ]) {
      if (on) {
        canvas.drawCircle(
          Offset(x, 57),
          5,
          Paint()
            ..color = color.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(
        Offset(x, 57),
        2,
        Paint()..color = on ? color : color.withValues(alpha: 0.3),
      );
    }
    final cockpit = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(28, 30), width: 10, height: 18),
      );
    canvas
      ..drawPath(cockpit, Paint()..color = theme.space)
      ..drawPath(
        cockpit,
        Paint()
          ..color = theme.flame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  void _missile(Canvas canvas) {
    final body = Path()
      ..moveTo(28, 0)
      ..cubicTo(34, 8, 35, 16, 35, 24)
      ..lineTo(35, 62)
      ..lineTo(21, 62)
      ..lineTo(21, 24)
      ..cubicTo(21, 16, 22, 8, 28, 0)
      ..close();
    final fins = Path()
      ..addPolygon(const [
        Offset(21, 46),
        Offset(10, 60),
        Offset(10, 66),
        Offset(21, 62),
      ], true)
      ..addPolygon(const [
        Offset(35, 46),
        Offset(46, 60),
        Offset(46, 66),
        Offset(35, 62),
      ], true)
      ..addPolygon(const [Offset(21, 22), Offset(16, 30), Offset(21, 32)], true)
      ..addPolygon(const [
        Offset(35, 22),
        Offset(40, 30),
        Offset(35, 32),
      ], true);
    // Smoke puffs behind the flame, growing and fading as they fall away.
    for (var i = 0; i < 4; i++) {
      final p = _cycle(700, i / 4);
      canvas.drawCircle(
        Offset(28 + 3 * sin(i * 2.1 + _t / 300), 82 + p * 10),
        2 + p * 5,
        Paint()..color = LS.muted.withValues(alpha: 0.28 * (1 - p)),
      );
    }
    _glow(canvas, body);
    _flame(canvas, 28, 64, 5, 26, pulse: 1 + 0.15 * sin(_t / 60));
    canvas
      ..drawPath(fins, Paint()..color = theme.trim)
      ..drawPath(body, Paint()..color = theme.hull)
      ..drawRect(
        const Rect.fromLTWH(21, 36, 14, 4),
        Paint()..color = theme.trim,
      )
      ..drawPath(
        Path()
          ..moveTo(28, 0)
          ..cubicTo(32, 5, 33.5, 10, 34, 14)
          ..lineTo(22, 14)
          ..cubicTo(22.5, 10, 24, 5, 28, 0)
          ..close(),
        Paint()..color = theme.flame,
      );
    // Spin: a light band sweeps across the body again and again.
    final x = 21 + 14 * _cycle(420);
    canvas
      ..save()
      ..clipPath(body)
      ..drawRect(
        Rect.fromLTWH(x - 2, 0, 4, 64),
        Paint()..color = LS.text.withValues(alpha: 0.45),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(ShipPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.kind != kind ||
      oldDelegate.theme != theme;
}
