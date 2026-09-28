import 'dart:math';

import 'package:flutter/material.dart';

import 'rocket_look.dart';

/// What a far-off planet looks like.
enum PlanetKind {
  /// Cloud bands with storm spots drifting across: it turns.
  gasGiant,

  /// A tilted ring whose back half passes behind the planet.
  ringed,

  /// A cratered world with a small moon going round it.
  moonOrbit,

  /// Continents and faster clouds sliding across a lit face.
  cloudWorld,
}

/// One planet in the loop: [x] across the field, [size] as a fraction of
/// its width, [speed] in field heights per second (far = small, dim, slow),
/// [phase] where it starts, [tint] which theme colour it takes.
typedef Planet = ({
  PlanetKind kind,
  double x,
  double size,
  double speed,
  double phase,
  double dim,
  int tint,
});

/// Farthest first, so nearer planets pass in front. Phases are spread so one
/// to three are in view at a time.
const List<Planet> planets = [
  (
    kind: PlanetKind.moonOrbit,
    x: 0.2,
    size: 0.13,
    speed: 0.004,
    phase: 0.55,
    dim: 0.6,
    tint: 0,
  ),
  (
    kind: PlanetKind.ringed,
    x: 0.8,
    size: 0.2,
    speed: 0.006,
    phase: 0.05,
    dim: 0.8,
    tint: 3,
  ),
  (
    kind: PlanetKind.cloudWorld,
    x: 0.72,
    size: 0.24,
    speed: 0.008,
    phase: 0.62,
    dim: 0.85,
    tint: 2,
  ),
  (
    kind: PlanetKind.gasGiant,
    x: 0.3,
    size: 0.36,
    speed: 0.011,
    phase: 0.95,
    dim: 1,
    tint: 1,
  ),
];

/// Distant scenery behind the stars: the [planets] drifting down and
/// looping, each animated its own way, and shooting stars streaking across
/// in random directions. A shooting star that runs into a planet stops there
/// in a tiny burst. Driven by flight time, so it all holds still while
/// paused, and fully determined by it (every star comes from a seeded
/// random), so the sky replays identically.
class SceneryPainter extends CustomPainter {
  SceneryPainter(this.time, this.theme);

  final Duration time;
  final SpaceTheme theme;

  /// Independent shooting-star streams, one star per period (seconds), at
  /// a random moment inside it.
  static const _streams = [2.7, 3.8, 5.3];

  /// How long a burst on a planet lasts, in seconds.
  static const _burst = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.inMicroseconds / Duration.microsecondsPerSecond;
    final tints = [theme.planet, ...theme.glows];
    for (final planet in planets) {
      final (center, radius) = _place(planet, t, size);
      _Drawn(
        canvas: canvas,
        center: center,
        radius: radius,
        tint: tints[planet.tint % tints.length],
        theme: theme,
        dim: planet.dim,
        t: t,
      ).draw(planet.kind);
    }
    for (var stream = 0; stream < _streams.length; stream++) {
      _shootingStar(canvas, size, t, stream);
    }
  }

  /// Where [planet] is at time [t] (seconds), and its radius.
  static (Offset, double) _place(Planet planet, double t, Size size) {
    final radius = size.width * planet.size / 2;
    // Loops over the field plus room to enter and leave fully (rings and
    // orbits reach past the disc).
    final span = size.height + radius * 6;
    final y =
        (planet.phase * span + t * planet.speed * size.height) % span -
        radius * 3;
    return (Offset(planet.x * size.width, y), radius);
  }

  /// The shooting star of [stream] in the pass that contains time [t]:
  /// where it flies, when, and how far along (0..1) it hits a planet, if it
  /// does.
  @visibleForTesting
  static ({
    Offset from,
    Offset to,
    double angle,
    double start,
    double duration,
    double? hitAt,
  })
  shootingStar(Size size, double t, int stream) {
    final period = _streams[stream];
    final pass = (t / period).floor();
    final r = Random(stream * 7919 + pass * 104729);
    final duration = 0.7 + r.nextDouble() * 0.8;
    // Room at the end of the period for a burst to finish.
    final start =
        pass * period + r.nextDouble() * max(0, period - duration - _burst);
    final from = Offset(
      size.width * (0.05 + r.nextDouble() * 0.9),
      size.height * (0.03 + r.nextDouble() * 0.75),
    );
    final angle = r.nextDouble() * 2 * pi;
    final length = size.width * (0.35 + r.nextDouble() * 0.45);
    final to = from + Offset(cos(angle), sin(angle)) * length;

    // Does it run into a planet on the way? (Planets move, so check where
    // each one is at that moment.)
    // A star that starts over a planet is simply passing in front of it;
    // only one coming in from open space can hit.
    bool over(Offset at, double time) => planets.any((planet) {
      final (center, radius) = _place(planet, time, size);
      return (at - center).distance < radius * 0.92;
    });
    double? hitAt;
    final clear = !over(from, start);
    for (var step = 1; clear && step <= 30 && hitAt == null; step++) {
      final v = step / 30;
      if (over(Offset.lerp(from, to, v)!, start + v * duration)) {
        hitAt = v;
      }
    }

    return (
      from: from,
      to: to,
      angle: angle,
      start: start,
      duration: duration,
      hitAt: hitAt,
    );
  }

  /// Number of shooting-star streams.
  static int get streams => _streams.length;

  void _shootingStar(Canvas canvas, Size size, double t, int stream) {
    final (:from, :to, :angle, :start, :duration, :hitAt) = shootingStar(
      size,
      t,
      stream,
    );
    final u = (t - start) / duration;
    if (u < 0) {
      return;
    }
    final end = hitAt ?? 1;
    if (u <= end) {
      // Head plus a fading tail, never reaching back past the start.
      final head = Offset.lerp(from, to, u)!;
      final tail = Offset.lerp(from, to, max(0, u - 0.28))!;
      final fade = hitAt == null ? sin(u * pi) : min(1.0, u * 4);
      canvas
        ..drawLine(
          tail,
          head,
          Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..shader = LinearGradient(
              colors: [
                theme.hull.withValues(alpha: 0),
                theme.hull.withValues(alpha: 0.75 * fade),
              ],
            ).createShader(Rect.fromPoints(tail, head)),
        )
        ..drawCircle(
          head,
          1.3,
          Paint()..color = theme.hull.withValues(alpha: fade),
        );
      return;
    }
    if (hitAt == null) {
      return;
    }
    // The burst: a flash, a ring opening out, and a few sparks.
    final age = (t - start - hitAt * duration) / _burst;
    if (age >= 1) {
      return;
    }
    final at = Offset.lerp(from, to, hitAt)!;
    final fade = 1 - age;
    canvas
      ..drawCircle(
        at,
        4 * fade + 1,
        Paint()
          ..color = theme.flame.withValues(alpha: 0.8 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawCircle(
        at,
        2 + age * 11,
        Paint()
          ..color = theme.hull.withValues(alpha: 0.6 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    for (var k = 0; k < 6; k++) {
      final a = angle + pi + (k - 2.5) * 0.45;
      canvas.drawCircle(
        at + Offset(cos(a), sin(a)) * (3 + age * 14),
        1.1 * fade,
        Paint()..color = theme.rock.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(SceneryPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.theme != theme;
}

/// Draws one planet of any kind at [center].
class _Drawn {
  _Drawn({
    required this.canvas,
    required this.center,
    required this.radius,
    required this.tint,
    required this.theme,
    required this.dim,
    required this.t,
  });

  final Canvas canvas;
  final Offset center;
  final double radius;
  final Color tint;
  final SpaceTheme theme;
  final double dim;
  final double t;

  Rect get _disc => Rect.fromCircle(center: center, radius: radius);

  /// [amount] of [tint] over the space colour, scaled by distance.
  Color _mix(Color color, double amount) =>
      Color.lerp(theme.space, color, (amount * dim).clamp(0, 1))!;

  void draw(PlanetKind kind) {
    switch (kind) {
      case PlanetKind.gasGiant:
        _atmosphere();
        _sphere(_gasBands);
      case PlanetKind.ringed:
        _ring(back: true);
        _atmosphere();
        _sphere(_softBands);
        _ring(back: false);
      case PlanetKind.moonOrbit:
        final angle = t * 0.35;
        final behind = sin(angle) < 0;
        if (behind) {
          _moon(angle);
        }
        _atmosphere();
        _sphere(_craters);
        if (!behind) {
          _moon(angle);
        }
      case PlanetKind.cloudWorld:
        _atmosphere();
        _sphere(_continentsAndClouds);
    }
  }

  /// Soft glow around the disc.
  void _atmosphere() => canvas.drawCircle(
    center,
    radius * 1.12,
    Paint()
      ..color = tint.withValues(alpha: 0.16 * dim)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.28),
  );

  /// The lit disc, [surface] painted on it (clipped), then the night side
  /// and a thin rim.
  void _sphere(void Function() surface) {
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.45),
            colors: [_mix(tint, 0.6), _mix(tint, 0.3), _mix(tint, 0.1)],
            stops: const [0, 0.55, 1],
          ).createShader(_disc),
      )
      ..save()
      ..clipPath(Path()..addOval(_disc));
    surface();
    canvas
      // Limb darkening: the edge curves away, so the disc reads as a ball.
      ..drawRect(
        _disc,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.2, -0.2),
            colors: [
              theme.space.withValues(alpha: 0),
              theme.space.withValues(alpha: 0),
              theme.space.withValues(alpha: 0.55),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(_disc),
      )
      // Night side: the lower right falls into deep shadow.
      ..drawRect(
        _disc,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.space.withValues(alpha: 0),
              theme.space.withValues(alpha: 0.15),
              theme.space.withValues(alpha: 0.92),
            ],
            stops: const [0, 0.45, 0.8],
          ).createShader(_disc),
      )
      ..restore()
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = tint.withValues(alpha: 0.4 * dim)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  /// The curve a band at [lat] (-1 top .. 1 bottom) follows across the
  /// disc: a latitude line seen from a little above, so it bows downward.
  /// Returns the point [p] (0 left .. 1 right) along it.
  Offset _alongBand(double lat, double p) {
    final halfWidth = radius * sqrt(max(0, 1 - lat * lat));
    final y = center.dy + lat * radius;
    final bow = radius * 0.16 * sqrt(max(0, 1 - lat * lat));
    final a = Offset(center.dx - halfWidth, y);
    final c = Offset(center.dx, y + bow * 2);
    final b = Offset(center.dx + halfWidth, y);
    // Quadratic Bézier from a through control c to b.
    return a * ((1 - p) * (1 - p)) + c * (2 * (1 - p) * p) + b * (p * p);
  }

  /// Soft, curved cloud bands: [bands] as (latitude, thickness, light).
  void _bands(List<(double, double, bool)> bands, double strength) {
    for (final (lat, thick, light) in bands) {
      final a = _alongBand(lat, 0);
      final b = _alongBand(lat, 1);
      final c = _alongBand(lat, 0.5) * 2 - (a + b) / 2;
      final width = radius * thick;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx - width, a.dy)
          ..quadraticBezierTo(c.dx, c.dy, b.dx + width, b.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.35)
          ..color = light
              ? Color.lerp(
                  tint,
                  theme.hull,
                  0.45,
                )!.withValues(alpha: 0.32 * strength * dim)
              : theme.space.withValues(alpha: 0.4 * strength * dim),
      );
    }
  }

  /// Gas giant: alternating soft bands, and storms riding two of them
  /// across the face (squashed near the edge), so the planet turns.
  void _gasBands() {
    _bands(const [
      (-0.72, 0.14, false),
      (-0.5, 0.18, true),
      (-0.25, 0.12, false),
      (-0.02, 0.22, true),
      (0.24, 0.12, false),
      (0.46, 0.18, true),
      (0.7, 0.14, false),
    ], 1);
    for (final (lat, speed, size) in [
      (-0.02, 0.018, 0.3),
      (0.46, 0.012, 0.2),
    ]) {
      final p = (t * speed + lat * 0.7 + 0.5) % 1.4 - 0.2;
      if (p <= 0.04 || p >= 0.96) {
        continue;
      }
      // Foreshortened toward the limb.
      final face = sqrt(max(0, 1 - pow(2 * p - 1, 2)));
      final at = _alongBand(lat, p);
      final storm = Rect.fromCenter(
        center: at,
        width: radius * size * face,
        height: radius * size * 0.42,
      );
      canvas
        ..drawOval(
          storm.inflate(radius * 0.03),
          Paint()
            ..color = theme.space.withValues(alpha: 0.35 * dim)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.03),
        )
        ..drawOval(
          storm,
          Paint()
            ..color = _mix(theme.rock, 0.7)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.015),
        );
    }
  }

  /// Faint, wide bands for the ringed planet.
  void _softBands() => _bands(const [
    (-0.45, 0.2, true),
    (-0.05, 0.16, false),
    (0.35, 0.22, true),
  ], 0.6);

  /// Craters for the moon-orbit world.
  void _craters() {
    const spots = [(-0.35, -0.2, 0.18), (0.25, 0.1, 0.12), (-0.05, 0.4, 0.1)];
    for (final (dx, dy, r) in spots) {
      final c = center + Offset(dx, dy) * radius;
      canvas
        ..drawCircle(c, radius * r, Paint()..color = _mix(theme.space, 0.5))
        ..drawCircle(
          c,
          radius * r,
          Paint()
            ..color = tint.withValues(alpha: 0.25 * dim)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
    }
  }

  /// Land masses sliding slowly and clouds a little faster.
  void _continentsAndClouds() {
    final land = _mix(theme.rock, 0.55);
    for (final (offset, dy, w, h) in [
      (0.0, -0.25, 0.7, 0.35),
      (0.55, 0.2, 0.5, 0.4),
      (1.1, -0.05, 0.4, 0.25),
    ]) {
      final x = (t * 0.01 + offset) % 1.6 - 0.3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx - radius + x * 2 * radius,
            center.dy + dy * radius,
          ),
          width: radius * w,
          height: radius * h,
        ),
        Paint()..color = land,
      );
    }
    for (final (offset, dy, w) in [(0.2, -0.45, 0.8), (0.9, 0.35, 0.6)]) {
      final x = (t * 0.02 + offset) % 1.6 - 0.3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx - radius + x * 2 * radius,
            center.dy + dy * radius,
          ),
          width: radius * w,
          height: radius * 0.14,
        ),
        Paint()..color = theme.hull.withValues(alpha: 0.35 * dim),
      );
    }
  }

  /// Half a tilted ring: the [back] half is drawn before the planet so the
  /// planet hides it; the front half after, crossing the planet.
  void _ring({required bool back}) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-0.35);
    for (final (scale, alpha, width) in [(1.0, 0.55, 2.2), (0.82, 0.3, 1.2)]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 3.3 * scale,
          height: radius * 0.8 * scale,
        ),
        back ? pi : 0,
        pi,
        false,
        Paint()
          ..color = tint.withValues(alpha: alpha * dim)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
    canvas.restore();
  }

  /// A small shaded moon on a tilted orbit at [angle].
  void _moon(double angle) {
    final c =
        center + Offset(cos(angle) * radius * 1.8, sin(angle) * radius * 0.45);
    final r = radius * 0.22;
    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [_mix(theme.hull, 0.75), _mix(theme.hull, 0.25)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      )
      ..drawCircle(
        c + Offset(r * 0.2, r * 0.1),
        r * 0.25,
        Paint()..color = _mix(theme.space, 0.4),
      );
  }
}
