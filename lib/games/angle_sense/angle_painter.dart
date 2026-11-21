import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'angle_sense_engine.dart';

/// Where the perfect reveal's arms have merged, as a share of its sweep;
/// the gold pulse plays after it and the chip shows from it.
const perfectMerge = 0.45;

/// How far (0–1) the reveal's gold arm has travelled from the answer to the
/// truth when the board's sweep controller is at [t]. Perfect closes quickly
/// then glows; close is the slow-motion easeInOutCubic (slowest as it closes
/// in); normal is the plain easeInOut.
double revealArm(RevealTier tier, double t) => switch (tier) {
  RevealTier.perfect => Curves.easeOutCubic.transform(
    (t / perfectMerge).clamp(0.0, 1.0),
  ),
  RevealTier.close => Curves.easeInOutCubic.transform(t),
  RevealTier.normal => Curves.easeInOut.transform(t),
};

/// The sharp-hit tint: gold leaning teal.
final Color sharpTint = Color.lerp(LS.teal, LS.gold, 0.5)!;

/// The colour of the gap in the loupe for [outcome].
Color gapColor(AngleOutcome outcome) =>
    outcome.grade.isHit ? sharpTint : LS.coral;

/// Paints the card: the scene for [question], the player's DRAW aim, and
/// after a lock the reveal: the player's answer as a dashed teal arm and a
/// gold arm [sweep] (0–1) of the way from it to the true angle. A perfect
/// answer merges both into one glowing gold line with a pulse at the vertex.
///
/// Geometry is in card units (0–1); strokes scale with the card so the
/// scene reads the same on a phone and a tablet.
class AnglePainter extends CustomPainter {
  const AnglePainter({
    required this.question,
    this.drawGuess,
    this.outcome,
    this.sweep = 0,
  });

  final AngleQuestion question;
  final int? drawGuess;
  final AngleOutcome? outcome;
  final double sweep;

  static double _rad(num deg) => deg * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final u = s / 320; // one prototype pixel
    final q = question;
    Offset at(Offset p) => Offset(p.dx * s, p.dy * s);
    Offset tip(double deg, double length) => at(q.point(deg, length));
    final vertex = at(q.vertex);

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * u
      ..strokeCap = StrokeCap.square;

    void line(Offset a, Offset b, Paint paint, {bool dashed = false}) {
      if (!dashed) {
        canvas.drawLine(a, b, paint);
        return;
      }
      final length = (b - a).distance;
      if (length == 0) {
        return;
      }
      final step = (b - a) / length;
      final dash = 8 * u, gap = 6 * u;
      for (var d = 0.0; d < length; d += dash + gap) {
        canvas.drawLine(a + step * d, a + step * min(d + dash, length), paint);
      }
    }

    /// An arc of [radius] card px from screen angle [from], [sweepDeg]
    /// counter-clockwise (negative: clockwise).
    void arc(double radius, double from, num sweepDeg, Paint paint) {
      canvas.drawArc(
        Rect.fromCircle(center: vertex, radius: radius * u),
        -_rad(from),
        -_rad(sweepDeg),
        false,
        paint,
      );
    }

    void label(String text, Offset centre, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        centre - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }

    void vertexSquare([double side = 8]) => canvas.drawRect(
      Rect.fromCenter(center: vertex, width: side * u, height: side * u),
      Paint()..color = LS.gold,
    );

    void dial({required bool letters, required bool hours}) {
      final r = 0.4 * s;
      canvas
        ..drawCircle(vertex, r, Paint()..color = LS.surface)
        ..drawCircle(vertex, r, stroke(LS.line, 2));
      if (hours) {
        for (var i = 0; i < 12; i++) {
          final major = i % 3 == 0;
          final deg = 90 - i * 30.0;
          line(
            vertex + Offset(cos(_rad(deg)), -sin(_rad(deg))) * (r - 6 * u),
            vertex +
                Offset(cos(_rad(deg)), -sin(_rad(deg))) *
                    (r - (major ? 22 : 14) * u),
            stroke(major ? LS.muted : LS.dim, major ? 3 : 2),
          );
        }
      } else {
        for (var i = 0; i < 36; i++) {
          final deg = i * 10.0;
          line(
            vertex + Offset(cos(_rad(deg)), -sin(_rad(deg))) * (r - 2 * u),
            vertex +
                Offset(cos(_rad(deg)), -sin(_rad(deg))) *
                    (r - (i % 9 == 0 ? 12 : 7) * u),
            stroke(LS.dim, 1.5),
          );
        }
      }
      if (letters) {
        const names = ['N', 'E', 'S', 'W'];
        for (var i = 0; i < 4; i++) {
          final deg = 90 - i * 90.0;
          label(
            names[i],
            vertex + Offset(cos(_rad(deg)), -sin(_rad(deg))) * (r - 24 * u),
            LSText.display(17 * u, color: i == 0 ? LS.coral : LS.muted),
          );
        }
      }
    }

    // Faint grid, like graph paper.
    final grid = stroke(LS.trace, 1);
    for (var i = 1; i < 8; i++) {
      final d = s * i / 8;
      canvas
        ..drawLine(Offset(d, 0), Offset(d, s), grid)
        ..drawLine(Offset(0, d), Offset(s, d), grid);
    }

    final arm = stroke(LS.text, 3);
    final gold = stroke(LS.gold, 2.5);
    final second = q.armAt(q.answer);

    switch (q.kind) {
      case AngleKind.flat ||
          AngleKind.vertical ||
          AngleKind.rays ||
          AngleKind.drawFlat ||
          AngleKind.drawRotated:
        final reading = q.rule == AngleRule.read;
        if (reading && q.decoy) {
          arc(26, second, q.dir * (360 - q.answer), stroke(LS.dim, 2));
        }
        if (reading) {
          arc(q.answer > 180 ? 30 : 34, q.base, q.dir * q.answer, gold);
        }
        line(vertex, tip(q.base, q.armLength), arm, dashed: q.dashed);
        if (reading) {
          line(vertex, tip(second, q.secondArmLength), arm, dashed: q.dashed);
        }
        vertexSquare();
      case AngleKind.crossed:
        for (final deg in [q.base, second]) {
          line(tip(deg + 180, q.armLength), tip(deg, q.armLength), arm);
        }
        arc(36, q.base, q.dir * q.answer, stroke(LS.gold, 3));
        vertexSquare();
      case AngleKind.clock:
        dial(letters: false, hours: true);
        arc(28, q.base, q.answer.toDouble(), gold);
        final hour = q.hour!, minute = q.minute!;
        final hourAt = 90 - (hour % 12) * 30 - minute / 2;
        final minuteAt = 90.0 - minute * 6;
        line(vertex, tip(hourAt, 0.2), stroke(LS.text, 5));
        line(vertex, tip(minuteAt, 0.3), arm);
        vertexSquare(10);
        label(
          '$hour:${minute.toString().padLeft(2, '0')}',
          vertex + Offset(0, 62 * u),
          LSText.mono(13 * u, color: LS.muted),
        );
      case AngleKind.pie:
        final r = q.armLength * s;
        canvas
          ..drawCircle(vertex, r, Paint()..color = LS.surface2)
          ..drawCircle(vertex, r, stroke(LS.line, 2));
        final wedge = Path()
          ..moveTo(vertex.dx, vertex.dy)
          ..arcTo(
            Rect.fromCircle(center: vertex, radius: r),
            -_rad(q.base),
            -_rad(q.dir * q.answer),
            false,
          )
          ..close();
        canvas
          ..drawPath(wedge, Paint()..color = LS.gold.withValues(alpha: 0.28))
          ..drawPath(wedge, stroke(LS.gold, 2));
      case AngleKind.bearing:
        dial(letters: true, hours: false);
        line(vertex, tip(90, 0.3), stroke(LS.dim, 2), dashed: true);
        arc(30, 90, -q.answer.toDouble(), gold);
        final needle = tip(second, q.armLength);
        line(vertex, needle, arm);
        canvas.drawCircle(needle, 5 * u, Paint()..color = LS.text);
        vertexSquare();
        label(
          'BEARING',
          vertex + Offset(0, 56 * u),
          LSText.mono(11 * u, color: LS.muted),
        );
      case AngleKind.triangle:
        final corners = Path()
          ..addPolygon([
            vertex,
            tip(q.base, q.armLength),
            tip(second, q.secondArmLength),
          ], true);
        canvas
          ..drawPath(corners, Paint()..color = LS.surface2)
          ..drawPath(
            corners,
            stroke(LS.text, 3)..strokeJoin = StrokeJoin.miter,
          );
        arc(34, q.base, q.answer.toDouble(), gold);
        vertexSquare();
      case AngleKind.drawClock || AngleKind.compassRound:
        final compass = q.kind == AngleKind.compassRound;
        dial(letters: compass, hours: !compass);
        line(vertex, tip(90, 0.34), stroke(LS.dim, 2), dashed: true);
        vertexSquare();
    }

    // DRAW: the player's aim, before the lock.
    final aim = drawGuess;
    final shown = outcome;
    if (shown == null && aim != null && q.rule == AngleRule.draw) {
      line(vertex, tip(q.armAt(aim), q.secondArmLength), stroke(LS.teal, 3));
      vertexSquare();
    }

    // Reveal: the player's answer stays dashed; the gold arm sweeps from it
    // to the truth.
    if (shown != null) {
      final from = shown.guess ?? q.answer;
      final delta = -AngleSenseEngine.signedError(from, q.answer);
      final now = from + delta * revealArm(shown.tier, sweep);
      final end = tip(q.armAt(now), q.secondArmLength);
      if (shown.tier == RevealTier.perfect) {
        _perfect(canvas, u, vertex, end, from, tip, line, sweep);
        return;
      }
      if (shown.guess != null) {
        line(
          vertex,
          tip(q.armAt(from), q.secondArmLength * 0.92),
          stroke(LS.teal, 3),
          dashed: true,
        );
      }
      line(vertex, end, stroke(LS.gold, 4));
      vertexSquare();
    }
  }

  /// The perfect reveal: the teal answer fades into the gold arm, which
  /// thickens and glows; then a square gold pulse leaves the vertex. At
  /// [t] = 1 (and so under reduce motion) only the glowing line is left.
  void _perfect(
    Canvas canvas,
    double u,
    Offset vertex,
    Offset end,
    int from,
    Offset Function(double, double) tip,
    void Function(Offset, Offset, Paint, {bool dashed}) line,
    double t,
  ) {
    final q = question;
    final merged = (t / perfectMerge).clamp(0.0, 1.0);
    final pulse = ((t - perfectMerge) / (1 - perfectMerge)).clamp(0.0, 1.0);
    if (outcome!.guess != null && merged < 1) {
      line(
        vertex,
        tip(q.armAt(from), q.secondArmLength * 0.92),
        Paint()
          ..color = LS.teal.withValues(alpha: 1 - merged)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * u,
        dashed: true,
      );
    }
    // The soft glow swells once during the pulse, then settles.
    final glow = merged * (0.4 + 0.35 * sin(pi * pulse));
    canvas
      ..drawLine(
        vertex,
        end,
        Paint()
          ..color = LS.gold.withValues(alpha: glow)
          ..strokeWidth = 14 * u
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * u),
      )
      ..drawLine(
        vertex,
        end,
        Paint()
          ..color = LS.gold
          ..strokeWidth = (4 + 2.5 * merged) * u
          ..strokeCap = StrokeCap.square,
      );
    if (pulse > 0 && pulse < 1) {
      final side = (10 + 44 * Curves.easeOut.transform(pulse)) * u;
      canvas.drawRect(
        Rect.fromCenter(center: vertex, width: side, height: side),
        Paint()
          ..color = LS.gold.withValues(alpha: 1 - pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * u,
      );
    }
    canvas.drawRect(
      Rect.fromCenter(center: vertex, width: 10 * u, height: 10 * u),
      Paint()..color = LS.gold,
    );
  }

  @override
  bool shouldRepaint(AnglePainter oldDelegate) =>
      oldDelegate.question != question ||
      oldDelegate.drawGuess != drawGuess ||
      oldDelegate.outcome != outcome ||
      oldDelegate.sweep != sweep;
}

/// The close reveal's magnified view of the arms' tips: the player's answer
/// (teal), the true angle (faint gold), the gap between them, and the gold
/// arm [sweep] (0–1) of the way across, at about ×5.
///
/// Strokes are not magnified, so a 2° gap stays clearly open.
class AngleLoupePainter extends CustomPainter {
  const AngleLoupePainter({
    required this.question,
    required this.outcome,
    required this.cardSide,
    required this.sweep,
  });

  final AngleQuestion question;
  final AngleOutcome outcome;

  /// The card's side in pixels (card units → pixels).
  final double cardSide;
  final double sweep;

  static const maxZoom = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final q = question;
    final rect = Offset.zero & size;
    canvas
      ..clipRect(rect)
      ..drawRect(rect, Paint()..color = LS.well);

    // A fine reticle grid, so the zoom reads as a zoom.
    final grid = Paint()
      ..color = LS.trace
      ..strokeWidth = 1;
    for (var d = 12.0; d < size.width; d += 12) {
      canvas.drawLine(Offset(d, 0), Offset(d, size.height), grid);
    }
    for (var d = 12.0; d < size.height; d += 12) {
      canvas.drawLine(Offset(0, d), Offset(size.width, d), grid);
    }

    final from = outcome.guess ?? q.answer;
    final delta = -AngleSenseEngine.signedError(from, q.answer);
    final r = q.secondArmLength;
    final mid = q.armAt(from + delta / 2);
    final gapAngle = delta.abs() * pi / 180;

    // Zoom ×5, less when a wide near miss would not fit; then centre a
    // little inside the tips so they show near the loupe's edge.
    final chord = max(2 * sin(gapAngle / 2) * r, 1e-6) * cardSide;
    final zoom = min(maxZoom, 0.6 * size.shortestSide / chord).clamp(1.5, 5.0);
    final scale = cardSide * zoom;
    final inset = 0.28 * size.shortestSide / scale;
    final focus = q.point(mid, max(r - inset, r * 0.5));
    Offset map(Offset card) =>
        size.center(Offset.zero) + (card - focus) * scale;

    final vertex = map(q.vertex);
    Offset tip(num deg) => map(q.point(q.armAt(deg).toDouble(), r));

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;

    // The gap, as an arc band at the focus radius.
    final gap = gapColor(outcome);
    final rf = (focus - q.vertex).distance * scale;
    final start = -q.armAt(from) * pi / 180;
    final sweepRad = -q.dir * delta * pi / 180;
    canvas
      ..drawArc(
        Rect.fromCircle(center: vertex, radius: rf),
        start,
        sweepRad,
        false,
        stroke(gap.withValues(alpha: 0.28), 10),
      )
      ..drawArc(
        Rect.fromCircle(center: vertex, radius: rf),
        start,
        sweepRad,
        false,
        stroke(gap, 2),
      );

    // The truth, faint until the gold arm lands on it.
    canvas.drawLine(
      vertex,
      tip(q.answer),
      stroke(LS.gold.withValues(alpha: 0.35), 1.5),
    );
    if (outcome.guess != null) {
      final guessTip = tip(from);
      canvas
        ..drawLine(vertex, guessTip, stroke(LS.teal, 3))
        ..drawRect(
          Rect.fromCenter(center: guessTip, width: 7, height: 7),
          Paint()..color = LS.teal,
        );
    }
    final now = from + delta * revealArm(RevealTier.close, sweep);
    final goldTip = tip(now);
    canvas
      ..drawLine(vertex, goldTip, stroke(LS.gold, 3))
      ..drawRect(
        Rect.fromCenter(center: goldTip, width: 7, height: 7),
        Paint()..color = LS.gold,
      );
  }

  @override
  bool shouldRepaint(AngleLoupePainter oldDelegate) =>
      oldDelegate.question != question ||
      oldDelegate.outcome != outcome ||
      oldDelegate.cardSide != cardSide ||
      oldDelegate.sweep != sweep;
}
