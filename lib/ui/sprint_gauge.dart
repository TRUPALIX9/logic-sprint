import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/sprint_level.dart';

/// Lit colour of each band, dim end to bright end.
Color sprintBandColor(SprintBand band) => switch (band) {
  SprintBand.top100 => LS.pink.withValues(alpha: 0.55),
  SprintBand.top50 => LS.violet.withValues(alpha: 0.7),
  SprintBand.top25 => LS.blue,
  SprintBand.top10 => LS.teal,
  SprintBand.top5 => LS.gold,
};

/// A band not lit: its shade at about 25%, so the arc still reads dim to
/// bright and shows the colours there are to reach.
Color _dimColor(SprintBand band) {
  final lit = sprintBandColor(band);
  return lit.withValues(alpha: lit.a * 0.25);
}

/// Sprint Score as a semicircle of five bands (Top 50–100% pink, 25–50%
/// purple, 10–25% blue, 5–10% teal, 0–5% gold), lit up to the player's
/// level, with a tick at their exact place and "TOP 7%" in the middle in
/// the band's colour. Below Top 20% (or with no runs) every band is drawn
/// dim, with no fill, no tick, no percentage and "PLAY MORE GAMES TO GET
/// IT" in the middle.
///
/// With [animate] the fill sweeps in over 700 ms the first time the gauge
/// is on screen and a gold band shimmers every few seconds; under reduce
/// motion it shows the final state at once and doesn't shimmer.
class SprintGauge extends StatefulWidget {
  const SprintGauge({
    super.key,
    required this.top,
    this.diameter = 200,
    this.animate = true,
  });

  /// "Top X percent", or null with no score yet.
  final int? top;
  final double diameter;
  final bool animate;

  static const sweep = Duration(milliseconds: 700);

  /// One shimmer pass plus the pause before the next.
  static const shimmerPeriod = Duration(milliseconds: 3200);

  static const hiddenText = 'Play more games to get it';

  @override
  State<SprintGauge> createState() => _SprintGaugeState();
}

class _SprintGaugeState extends State<SprintGauge>
    with TickerProviderStateMixin {
  // Preserve: reduce motion is handled here (final state, no sweep), so the
  // platform must not shorten it on its own.
  late final _fill = AnimationController(
    vsync: this,
    duration: SprintGauge.sweep,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onFill);
  late final _curve = CurvedAnimation(
    parent: _fill,
    curve: Curves.easeOutCubic,
  );
  AnimationController? _shimmer;
  bool _started = false;

  bool get _gold => SprintLevel(widget.top).band == SprintBand.top5;

  bool get _motion =>
      widget.animate && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motion) {
      _fill.value = 1;
      _started = true;
      _stopShimmer();
      return;
    }
    // Profile sits in an IndexedStack, built before it is shown: wait until
    // tickers run (the tab is visible) so the sweep isn't spent off screen.
    if (!_started && TickerMode.valuesOf(context).enabled) {
      _started = true;
      _fill.forward();
    }
  }

  @override
  void didUpdateWidget(SprintGauge old) {
    super.didUpdateWidget(old);
    if (old.top != widget.top && _fill.isCompleted) {
      _onFill(AnimationStatus.completed);
    }
  }

  void _onFill(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    final shine = _gold && _motion;
    if (shine == (_shimmer != null)) {
      return;
    }
    if (shine) {
      _shimmer = AnimationController(
        vsync: this,
        duration: SprintGauge.shimmerPeriod,
      )..repeat();
    } else {
      _stopShimmer();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _stopShimmer() {
    _shimmer?.dispose();
    _shimmer = null;
  }

  @override
  void dispose() {
    _stopShimmer();
    _curve.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = SprintLevel(widget.top);
    final d = widget.diameter;
    final stroke = SprintGaugePainter.strokeFor(d);
    final label = level.label;
    final band = level.band;
    final color = band == null ? LS.muted : sprintBandColor(band);
    final shimmer = _shimmer;
    return Semantics(
      container: true,
      label: label == null
          ? SprintGauge.hiddenText
          : 'Top ${level.top} percent of players',
      child: ExcludeSemantics(
        child: SizedBox(
          width: d,
          height: d / 2 + stroke,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_curve, ?shimmer]),
                  builder: (context, _) => CustomPaint(
                    painter: SprintGaugePainter(
                      level: level,
                      progress: _curve.value,
                      shimmer: shimmer?.value,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: stroke * 2.2,
                right: stroke * 2.2,
                bottom: 0,
                child: label == null
                    ? Text(
                        SprintGauge.hiddenText.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LSText.mono(
                          math.max(10, d * 0.055),
                          weight: FontWeight.w700,
                          color: LS.muted,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label.toUpperCase(),
                          style:
                              LSText.mono(
                                d * 0.16,
                                weight: FontWeight.w700,
                                spacing: 0,
                                color: color,
                              ).copyWith(
                                shadows: band == SprintBand.top5
                                    ? [
                                        Shadow(
                                          color: LS.gold.withValues(alpha: 0.6),
                                          blurRadius: d * 0.06,
                                        ),
                                      ]
                                    : null,
                              ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the gauge. [progress] (0–1) is how far toward the player's level
/// the fill has swept; [shimmer] (0–1 through one period) moves a glint
/// along a lit gold band, null for none.
class SprintGaugePainter extends CustomPainter {
  const SprintGaugePainter({
    required this.level,
    required this.progress,
    this.shimmer,
  });

  final SprintLevel level;
  final double progress;
  final double? shimmer;

  /// About 12 px on a 200 px gauge.
  static double strokeFor(double diameter) => diameter * 0.06;

  /// Gap between bands.
  static const gap = 2 * math.pi / 180;

  /// Part of each shimmer period the glint is moving; the rest is a pause.
  static const _glintShare = 0.3;

  /// Fill end along the arc right now (0–1).
  double get fillEnd => level.position * progress.clamp(0, 1);

  /// Bands with any lit part.
  List<SprintBand> get litBands => [
    for (final b in SprintBand.values)
      if (litFraction(b) > 0) b,
  ];

  /// How much of [band] is lit (0–1).
  double litFraction(SprintBand band) =>
      (fillEnd * SprintBand.values.length - band.index).clamp(0, 1).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokeFor(size.width);
    // Room for the gold glow and the tick around the arc.
    final radius = size.width / 2 - stroke;
    final center = Offset(size.width / 2, radius + stroke);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final n = SprintBand.values.length;
    final bandSweep = (math.pi - gap * (n - 1)) / n;
    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = color;

    for (final band in SprintBand.values) {
      final start = math.pi + band.index * (bandSweep + gap);
      canvas.drawArc(rect, start, bandSweep, false, arc(_dimColor(band)));
      final lit = litFraction(band);
      if (lit <= 0) {
        continue;
      }
      final color = sprintBandColor(band);
      final litSweep = bandSweep * lit;
      if (band == SprintBand.top5) {
        canvas.drawArc(
          rect,
          start,
          litSweep,
          false,
          arc(color.withValues(alpha: 0.5))
            ..strokeWidth = stroke + 4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawArc(rect, start, litSweep, false, arc(color));
      final shimmer = this.shimmer;
      if (band == SprintBand.top5 && shimmer != null && shimmer < _glintShare) {
        final glint = bandSweep * 0.35;
        final t = shimmer / _glintShare;
        final from = start - glint + (litSweep + glint) * t;
        final a = math.max(from, start);
        final b = math.min(from + glint, start + litSweep);
        if (b > a) {
          canvas.drawArc(
            rect,
            a,
            b - a,
            false,
            arc(Colors.white.withValues(alpha: 0.45))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      }
    }

    if (!level.ranked || progress <= 0) {
      return;
    }
    // Tick: a short chamfered bar across the arc at the fill end.
    final along = fillEnd * n;
    final index = along.floor().clamp(0, n - 1);
    final angle =
        math.pi + index * (bandSweep + gap) + (along - index) * bandSweep;
    final inner = radius - stroke / 2 - stroke * 0.4;
    final outer = radius + stroke / 2 + stroke * 0.4;
    final half = math.max(2.0, stroke * 0.2);
    final cut = half * 0.6;
    final tick = Path()
      ..moveTo(inner + cut, -half)
      ..lineTo(outer, -half)
      ..lineTo(outer, half - cut)
      ..lineTo(outer - cut, half)
      ..lineTo(inner, half)
      ..lineTo(inner, -half + cut)
      ..close();
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..drawPath(tick, Paint()..color = LS.text)
      ..restore();
  }

  @override
  bool shouldRepaint(SprintGaugePainter old) =>
      old.level.top != level.top ||
      old.progress != progress ||
      old.shimmer != shimmer;
}
