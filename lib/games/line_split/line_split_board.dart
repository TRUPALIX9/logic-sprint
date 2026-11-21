import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import '../../ui/reveal.dart';
import 'line_split_engine.dart';

/// Space kept round the line inside the card for the 0 and 1 labels.
const _margin = 34.0;

/// How far above the finger the floating marker sits (about one thumb).
const _thumb = 76.0;

/// The status row (stage, strikes, window), the target, the card holding
/// the line, the countdown bar and a hint. Kept apart from the round host so
/// tests can pump it on its own.
class LineSplitBoard extends StatelessWidget {
  const LineSplitBoard({super.key, required this.engine});

  final LineSplitEngine engine;

  @override
  Widget build(BuildContext context) {
    final question = engine.question;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusRow(engine: engine),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Center(
              child: Reveal(
                revealKey: question,
                hidden: engine.isResuming,
                child: TargetLabel(target: question.target),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ChamferBox(
              cut: Cut.lg,
              color: LS.well,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Reveal(
                    revealKey: question,
                    hidden: engine.isResuming,
                    child: _LineCard(engine: engine),
                  ),
                  // A restored shield waits out the get-ready countdown.
                  Positioned(
                    top: 10,
                    right: 12,
                    child: ShieldRow(
                      left: engine.isResuming ? 0 : engine.strikesLeft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CountdownBar(
            key: ValueKey(engine.questionStartedAt),
            limit: engine.timeLimit,
            left: engine.timeLeft,
            running: !engine.locked,
          ),
          const SizedBox(height: 12),
          const ExcludeSemantics(
            child: Center(
              child: MonoLabel('Press, slide along the line, let go'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.engine});

  final LineSplitEngine engine;

  @override
  Widget build(BuildContext context) {
    final number = engine.number.toString().padLeft(2, '0');
    return Row(
      children: [
        Expanded(
          child: MonoLabel('${engine.stage.title} · Q$number', size: 11),
        ),
        Expanded(
          child: Semantics(
            label: 'Window plus or minus ${_percent(engine.window)} percent',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const MonoLabel('Window '),
                MonoLabel(
                  '±${_percent(engine.window)}%',
                  color: GameId.lineSplit.accent,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// The shields left this run ([LineSplitEngine.maxStrikes] slots), gold in
/// the card's top-right corner. A lost one breaks (see [Shield]).
class ShieldRow extends StatelessWidget {
  const ShieldRow({super.key, required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Shields: $left of ${LineSplitEngine.maxStrikes}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < LineSplitEngine.maxStrikes; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Shield(key: ValueKey('shield-$i'), full: i < left),
          ],
        ],
      ),
    );
  }
}

/// One angular gold shield. Losing it ([full] true → false) flashes white,
/// splits it into two halves that drift apart and fade, sheds gold shards
/// and fires a medium haptic, over [breakTime]. Getting it back pops it in
/// (0.6 → 1 over [popTime]). Reduce motion: it just switches.
class Shield extends StatefulWidget {
  const Shield({super.key, required this.full});

  static const breakTime = Duration(milliseconds: 450);
  static const popTime = Duration(milliseconds: 250);
  static const size = Size(18, 20);

  final bool full;

  @override
  State<Shield> createState() => _ShieldState();
}

class _ShieldState extends State<Shield> with TickerProviderStateMixin {
  late final _break = AnimationController(
    vsync: this,
    duration: Shield.breakTime,
  )..value = 1;
  late final _pop = AnimationController(vsync: this, duration: Shield.popTime)
    ..value = 1;

  @override
  void didUpdateWidget(covariant Shield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.full == widget.full) {
      return;
    }
    final calm = MediaQuery.disableAnimationsOf(context);
    if (!widget.full) {
      HapticFeedback.mediumImpact();
      _pop.value = 1;
      calm ? _break.value = 1 : _break.forward(from: 0);
    } else {
      _break.value = 1;
      calm ? _pop.value = 1 : _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _break.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_break, _pop]),
      builder: (context, _) {
        final pop = Curves.easeOutBack.transform(_pop.value);
        return Transform.scale(
          scale: widget.full ? 0.6 + 0.4 * pop : 1,
          child: CustomPaint(
            size: Shield.size,
            painter: ShieldPainter(
              full: widget.full,
              breaking: widget.full ? 1 : _break.value,
            ),
          ),
        );
      },
    );
  }
}

/// A shield with chamfered shoulders and a pointed base. [breaking] runs
/// 0 → 1 through the break; at 1 a lost shield is a dim outline.
class ShieldPainter extends CustomPainter {
  ShieldPainter({required this.full, required this.breaking});

  final bool full;
  final double breaking;

  static Path outline(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.22, 0)
      ..lineTo(w * 0.78, 0)
      ..lineTo(w, h * 0.18)
      ..lineTo(w, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.58)
      ..lineTo(0, h * 0.18)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = outline(size);
    final dim = Paint()
      ..color = LS.gold.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (!full) {
      canvas.drawPath(shape, dim);
    }
    final t = breaking;
    if (!full && t >= 1) {
      return;
    }
    if (full) {
      _solid(canvas, size, shape, 1);
      return;
    }
    // Breaking: two halves drift apart, turn and fade; shards fly out.
    final fade = 1 - t;
    final mid = size.width / 2;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      final pivot = Offset(mid, size.height);
      canvas.translate(pivot.dx + side * 6 * t, pivot.dy + 2 * t);
      canvas.rotate(side * 0.35 * t);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.clipRect(
        side < 0
            ? Rect.fromLTWH(-2, -2, mid + 2, size.height + 4)
            : Rect.fromLTWH(mid, -2, mid + 2, size.height + 4),
      );
      _solid(canvas, size, shape, fade);
      // A white flash over the first quarter.
      final flash = (1 - t / 0.25).clamp(0.0, 1.0);
      if (flash > 0) {
        canvas.drawPath(
          shape,
          Paint()..color = Colors.white.withValues(alpha: flash * 0.9),
        );
      }
      canvas.restore();
    }
    final shard = Paint()..color = LS.gold.withValues(alpha: fade);
    final center = Offset(mid, size.height * 0.45);
    const angles = [-2.4, -0.7, 0.6, 2.2];
    for (final a in angles) {
      final at = center + Offset(cos(a), sin(a)) * (4 + 14 * t);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - 2)
          ..lineTo(at.dx + 2, at.dy + 1.5)
          ..lineTo(at.dx - 2, at.dy + 1.5)
          ..close(),
        shard,
      );
    }
  }

  /// Solid gold with a subtle inner line.
  static void _solid(Canvas canvas, Size size, Path shape, double opacity) {
    canvas.drawPath(shape, Paint()..color = LS.gold.withValues(alpha: opacity));
    final inner = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.5, size.height * 0.8);
    canvas.drawPath(
      inner,
      Paint()
        ..color = LS.bg.withValues(alpha: 0.3 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawPath(
      shape.transform(
        (Matrix4.identity()
              ..translateByDouble(size.width * 0.18, size.height * 0.15, 0, 1)
              ..scaleByDouble(0.64, 0.64, 1, 1))
            .storage,
      ),
      Paint()
        ..color = LS.bg.withValues(alpha: 0.22 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(ShieldPainter oldDelegate) =>
      oldDelegate.full != full || oldDelegate.breaking != breaking;
}

/// The target: a stacked fraction, or "0.43" / "37%", with a subtitle.
class TargetLabel extends StatelessWidget {
  const TargetLabel({super.key, required this.target});

  final SplitTarget target;

  @override
  Widget build(BuildContext context) {
    final accent = GameId.lineSplit.accent;
    final text = target.text;
    return Semantics(
      label: 'Target ${target.spoken}',
      excludeSemantics: true,
      // The value with its subtitle centred under it, as one group.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _value(text, accent),
            const SizedBox(height: 6),
            MonoLabel(target.subtitle),
          ],
        ),
      ),
    );
  }
}

extension on TargetLabel {
  /// "0.43", a stacked fraction (11 over 8), or a mixed number: a big whole
  /// beside a small stacked fraction (1½).
  Widget _value(String? text, Color accent) {
    final big = LSText.mono(
      46,
      color: accent,
      weight: FontWeight.w700,
      spacing: 0,
    );
    if (text != null) {
      return Text(text, style: big);
    }
    final fraction = StackedFraction(
      numerator: target.numerator!,
      denominator: target.denominator!,
      color: accent,
      size: target.whole > 0 ? 20 : 32,
    );
    if (target.whole == 0) {
      return fraction;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${target.whole}', style: big.copyWith(height: 1)),
        const SizedBox(width: 4),
        fraction,
      ],
    );
  }
}

/// A real fraction: numerator over a bar over denominator.
class StackedFraction extends StatelessWidget {
  const StackedFraction({
    super.key,
    required this.numerator,
    required this.denominator,
    required this.color,
    this.size = 32,
  });

  final int numerator;
  final int denominator;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = LSText.mono(
      size,
      color: color,
      weight: FontWeight.w700,
      spacing: 0,
    ).copyWith(height: 1);
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$numerator', style: style, textAlign: TextAlign.center),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: SizedBox(height: 3, child: ColoredBox(color: color)),
          ),
          Text('$denominator', style: style, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// The line, the live marker, the floating copy above the finger, the
/// reveal and the verdict chip. Press, slide, lift to answer.
class _LineCard extends StatefulWidget {
  const _LineCard({required this.engine});

  final LineSplitEngine engine;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard>
    with SingleTickerProviderStateMixin {
  final _finger = ValueNotifier<Offset?>(null);
  int? _pointer;
  Size _size = Size.zero;

  /// 0 to 1 over the reveal of the current outcome: the golden pulse
  /// ([LineSplitEngine.perfectPause]) or the slow-motion slide
  /// ([LineSplitEngine.closeSlide]). Decorative: reduce motion jumps it to 1
  /// (the engine's pauses don't change).
  late final AnimationController _reveal = AnimationController(vsync: this);
  SplitOutcome? _seen;
  bool _calm = false;

  LineSplitEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _seen = engine.outcome;
    _reveal.value = _seen == null ? 0 : 1;
    engine.addListener(_onEngine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    if (_calm && _seen != null) {
      _reveal
        ..stop()
        ..value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _LineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != engine) {
      oldWidget.engine.removeListener(_onEngine);
      engine.addListener(_onEngine);
      _onEngine();
    }
  }

  /// Starts the reveal for a new outcome, and holds it while the run is
  /// paused.
  void _onEngine() {
    final outcome = engine.outcome;
    if (!identical(outcome, _seen)) {
      _seen = outcome;
      _reveal.stop();
      if (outcome == null) {
        _reveal.value = 0;
        return;
      }
      final duration = switch (outcome.tier) {
        RevealTier.perfect => LineSplitEngine.perfectPause,
        RevealTier.close => LineSplitEngine.closeSlide,
        RevealTier.normal => Duration.zero,
      };
      _reveal.duration = duration;
      if (_calm || duration == Duration.zero) {
        _reveal.value = 1;
      } else {
        _reveal.forward(from: 0);
      }
      return;
    }
    if (outcome == null || _reveal.isCompleted) {
      return;
    }
    if (engine.isPlaying) {
      if (!_reveal.isAnimating) {
        _reveal.forward();
      }
    } else {
      _reveal.stop();
    }
  }

  Rect get _frame => (Offset.zero & _size).deflate(_margin);

  double _project(Offset point) => engine.question.line.project(_frame, point);

  void _down(PointerDownEvent event) {
    if (_pointer != null || engine.locked) {
      return;
    }
    _pointer = event.pointer;
    _finger.value = event.localPosition;
    engine.grab(_project(event.localPosition));
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    if (engine.locked) {
      _end();
      return;
    }
    _finger.value = event.localPosition;
    engine.aimAt(_project(event.localPosition));
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _end();
    engine.release();
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _end();
    engine.dropAim();
  }

  void _end() {
    _pointer = null;
    _finger.value = null;
  }

  @override
  void dispose() {
    engine.removeListener(_onEngine);
    _reveal.dispose();
    _finger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = engine.question;
    final outcome = engine.outcome;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final loupe = outcome?.tier == RevealTier.close
            ? LoupeLayout.of(_size, question, outcome!, _margin)
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<double?>(
              valueListenable: engine.aim,
              builder: (context, aim, child) => Semantics(
                slider: true,
                label:
                    '${_describe(question)}. Target ${question.target.spoken}. Your mark',
                value: '${((aim ?? 0.5) * 100).round()}%',
                increasedValue:
                    '${(min(1.0, (aim ?? 0.5) + 0.01) * 100).round()}%',
                decreasedValue:
                    '${(max(0.0, (aim ?? 0.5) - 0.01) * 100).round()}%',
                onIncrease: engine.locked ? null : () => engine.nudge(0.01),
                onDecrease: engine.locked ? null : () => engine.nudge(-0.01),
                customSemanticsActions: engine.locked
                    ? null
                    : {
                        const CustomSemanticsAction(label: 'Answer'): () {
                          if (engine.aim.value == null) {
                            engine.aimAt(0.5);
                          }
                          engine.release();
                        },
                      },
                child: child,
              ),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: _cancel,
                child: CustomPaint(
                  painter: LinePainter(
                    question: question,
                    outcome: outcome,
                    aim: engine.aim,
                    finger: _finger,
                    margin: _margin,
                    reveal: _reveal,
                    loupe: loupe,
                  ),
                ),
              ),
            ),
            if (loupe != null)
              Positioned.fromRect(
                rect: loupe.rect,
                child: RevealLoupe(
                  layout: loupe,
                  question: question,
                  outcome: outcome!,
                  reveal: _reveal,
                ),
              ),
            if (outcome != null)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(child: VerdictChip(outcome: outcome)),
              ),
          ],
        );
      },
    );
  }

  static String _describe(SplitQuestion question) {
    final line = question.line;
    final units = question.target.units;
    final where = line.isFlat
        ? '0 at the left, $units at the right'
        : line.isUpright
        ? '0 at the bottom, $units at the top'
        : line.degrees > 0
        ? '0 at the lower left, $units at the upper right'
        : '0 at the upper left, $units at the lower right';
    final extras = [
      if (units > 1)
        question.target.unitTicks
            ? 'whole numbers marked along it'
            : 'only its ends labelled',
      if (question.decoy != null) 'a faint decoy line crosses it',
      if (question.ticks.isNotEmpty) '${question.ticks.length} fake tick marks',
    ];
    return ['A line with $where', ...extras].join(', ');
  }
}

/// The outcome's headline: gold "PERFECT +0.4%", pink "SHARP +1.6%", teal
/// for a hit, coral "SO CLOSE +7.0%" for a near miss and coral for a miss or
/// a timeout.
class VerdictChip extends StatelessWidget {
  const VerdictChip({super.key, required this.outcome});

  final SplitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final color = outcome.tier == RevealTier.perfect
        ? LS.gold
        : switch (outcome.verdict) {
            SplitVerdict.bullseye ||
            SplitVerdict.sharp => GameId.lineSplit.accent,
            SplitVerdict.hit => LS.teal,
            SplitVerdict.miss || SplitVerdict.time => LS.coral,
          };
    return Semantics(
      liveRegion: true,
      child: ChamferBox(
        cut: Cut.sm,
        color: Color.alphaBlend(color.withValues(alpha: 0.15), LS.well),
        borderColor: null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: DisplayText(outcome.headline, size: 20, color: color),
      ),
    );
  }
}

/// Paints the grid, the line with its end and whole-number labels, decoys,
/// the live marker and its floating copy, and the reveal: the golden line of
/// a perfect answer, or the gap with zoom guides to the loupe.
class LinePainter extends CustomPainter {
  LinePainter({
    required this.question,
    required this.outcome,
    required this.aim,
    required this.finger,
    required this.margin,
    required this.reveal,
    this.loupe,
  }) : super(repaint: Listenable.merge([aim, finger, reveal]));

  final SplitQuestion question;
  final SplitOutcome? outcome;
  final ValueNotifier<double?> aim;
  final ValueNotifier<Offset?> finger;
  final double margin;

  /// 0 to 1 through the reveal (see the card's controller).
  final Animation<double> reveal;

  /// Where the slow-motion zoom sits, for a close reveal.
  final LoupeLayout? loupe;

  static const _grid = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = (Offset.zero & size).deflate(margin);
    if (frame.isEmpty) {
      return;
    }
    final line = question.line;
    final accent = GameId.lineSplit.accent;

    final grid = Paint()..color = LS.trace;
    for (var x = 0.0; x <= size.width; x += _grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += _grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final decoy = question.decoy;
    if (decoy != null) {
      final faint = Paint()
        ..color = LS.dim.withValues(alpha: 0.45)
        ..strokeWidth = 2.5;
      canvas.drawLine(decoy.start(frame), decoy.end(frame), faint);
      _tick(canvas, decoy, frame, 0, 8, faint);
      _tick(canvas, decoy, frame, 1, 8, faint);
    }

    final result = outcome;
    final target = question.target;
    final t = reveal.value;
    final perfect = result?.tier == RevealTier.perfect;
    // The line turns gold over the first quarter of a perfect reveal.
    final golden = perfect
        ? Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0))
        : 0.0;
    if (golden > 0) {
      canvas.drawLine(
        line.start(frame),
        line.end(frame),
        Paint()
          ..color = LS.gold.withValues(alpha: 0.35 * golden)
          ..strokeWidth = 14
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    final solid = Paint()
      ..color = Color.lerp(LS.text, LS.gold, golden)!
      ..strokeWidth = 4;
    canvas.drawLine(line.start(frame), line.end(frame), solid);
    _tick(canvas, line, frame, 0, 12, solid);
    _tick(canvas, line, frame, 1, 12, solid);

    // The inner whole numbers of a longer line; hidden ones show once
    // answered.
    final units = target.units;
    if (units > 1 && (target.unitTicks || result != null)) {
      final inner = Paint()
        ..color = solid.color.withValues(alpha: target.unitTicks ? 1 : 0.6)
        ..strokeWidth = 3;
      for (var k = 1; k < units; k++) {
        _tick(canvas, line, frame, k / units, 9, inner);
        _label(canvas, line, frame, k / units, '$k', LS.muted);
      }
    }

    final fake = Paint()
      ..color = LS.dim
      ..strokeWidth = 2;
    for (final u in question.ticks) {
      _tick(canvas, line, frame, u, 7, fake);
    }

    _label(canvas, line, frame, 0, '0', LS.dim);
    _label(canvas, line, frame, 1, '$units', target.fromOne ? accent : LS.dim);

    if (result != null) {
      final answer = result.answer;
      final truth = target.position;
      if (perfect) {
        _perfect(canvas, line, frame, truth, t);
        return;
      }
      final zoom = loupe;
      if (zoom != null) {
        _guides(canvas, line, frame, zoom, LoupeLayout.appear(t));
      }
      if (answer != null) {
        canvas.drawLine(
          line.at(frame, answer),
          line.at(frame, truth),
          Paint()
            ..color = gapColor(result).withValues(alpha: 0.55)
            ..strokeWidth = 8,
        );
      }
      _tick(
        canvas,
        line,
        frame,
        truth,
        20,
        Paint()
          ..color = accent
          ..strokeWidth = 4,
      );
      if (answer != null) {
        _dashedTick(canvas, line, frame, answer, 17);
      }
      return;
    }

    final live = aim.value;
    if (live == null) {
      return;
    }
    final marker = Paint()
      ..color = LS.teal
      ..strokeWidth = 3;
    _tick(canvas, line, frame, live, 22, marker);

    final touch = finger.value;
    if (touch != null) {
      _loupe(canvas, size, line, frame, live, touch);
    }
  }

  /// The gap's colour: the line's pink for a Sharp, coral otherwise.
  static Color gapColor(SplitOutcome outcome) =>
      outcome.tier == RevealTier.close && outcome.verdict.isHit
      ? GameId.lineSplit.accent
      : LS.coral;

  /// One gold tick where both ticks meet, and a gold pulse running from it
  /// to both ends (gone by the end, so reduce motion shows none).
  void _perfect(
    Canvas canvas,
    SplitLine line,
    Rect frame,
    double truth,
    double t,
  ) {
    _tick(
      canvas,
      line,
      frame,
      truth,
      22,
      Paint()
        ..color = LS.gold.withValues(alpha: 0.5)
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    _tick(
      canvas,
      line,
      frame,
      truth,
      22,
      Paint()
        ..color = LS.gold
        ..strokeWidth = 4,
    );
    final travel = Curves.easeOutCubic.transform(t);
    final fade = 1 - travel;
    if (fade <= 0.01) {
      return;
    }
    final pulse = Paint()
      ..color = LS.gold.withValues(alpha: fade)
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final end in const [0.0, 1.0]) {
      final u = truth + (end - truth) * travel;
      final a = (u - 0.025).clamp(0.0, 1.0);
      final b = (u + 0.025).clamp(0.0, 1.0);
      canvas.drawLine(line.at(frame, a), line.at(frame, b), pulse);
    }
  }

  /// A thin bracket round the stretch of line the loupe magnifies, and two
  /// guide lines from it to the loupe's near edge, so it reads as a zoom.
  void _guides(
    Canvas canvas,
    SplitLine line,
    Rect frame,
    LoupeLayout zoom,
    double opacity,
  ) {
    if (opacity <= 0) {
      return;
    }
    final paint = Paint()
      ..color = LS.muted.withValues(alpha: 0.6 * opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final s0 = line.at(frame, zoom.from.clamp(0.0, 1.0));
    final s1 = line.at(frame, zoom.to.clamp(0.0, 1.0));
    final n = _normal(line) * 13;
    canvas.drawPath(
      Path()
        ..moveTo((s0 - n).dx, (s0 - n).dy)
        ..lineTo((s1 - n).dx, (s1 - n).dy)
        ..lineTo((s1 + n).dx, (s1 + n).dy)
        ..lineTo((s0 + n).dx, (s0 + n).dy)
        ..close(),
      paint,
    );
    final (c0, c1) = zoom.nearCorners;
    final straight = (s0 - c0).distance + (s1 - c1).distance;
    final crossed = (s0 - c1).distance + (s1 - c0).distance;
    final (to0, to1) = straight <= crossed ? (c0, c1) : (c1, c0);
    canvas.drawLine(s0, to0, paint);
    canvas.drawLine(s1, to1, paint);
  }

  /// A small plate about a thumb above the finger, showing the line and the
  /// marker so the finger doesn't hide where it is.
  void _loupe(
    Canvas canvas,
    Size size,
    SplitLine line,
    Rect frame,
    double live,
    Offset touch,
  ) {
    const half = 26.0;
    var center = touch - const Offset(0, _thumb);
    if (center.dy < half + 4) {
      // No room above: sit beside the finger instead.
      final side = touch.dx > size.width / 2 ? -_thumb : _thumb;
      center = touch + Offset(side, 0);
    }
    center = Offset(
      center.dx.clamp(half + 4, max(half + 4, size.width - half - 4)),
      center.dy.clamp(half + 4, max(half + 4, size.height - half - 4)),
    );
    final plate = Rect.fromCenter(
      center: center,
      width: half * 2,
      height: half * 2,
    );
    final path = chamfer(Cut.sm).getOuterPath(plate);
    canvas.drawPath(path, Paint()..color = LS.surface2);
    canvas.drawPath(
      path,
      Paint()
        ..color = LS.line
        ..style = PaintingStyle.stroke,
    );
    canvas.save();
    canvas.clipPath(path);
    final dir = line.direction;
    final normal = Offset(-dir.dy, dir.dx);
    canvas.drawLine(
      center - dir * half,
      center + dir * half,
      Paint()
        ..color = LS.text
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      center - normal * 14,
      center + normal * 14,
      Paint()
        ..color = LS.teal
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  static Offset _normal(SplitLine line) {
    final dir = line.direction;
    return Offset(-dir.dy, dir.dx);
  }

  static void _tick(
    Canvas canvas,
    SplitLine line,
    Rect frame,
    double u,
    double half,
    Paint paint,
  ) {
    final at = line.at(frame, u);
    final normal = _normal(line) * half;
    canvas.drawLine(at - normal, at + normal, paint);
  }

  static void _dashedTick(
    Canvas canvas,
    SplitLine line,
    Rect frame,
    double u,
    double half,
  ) {
    final paint = Paint()
      ..color = LS.teal
      ..strokeWidth = 3;
    final at = line.at(frame, u);
    final normal = _normal(line);
    for (var d = -half; d < half; d += 9) {
      canvas.drawLine(at + normal * d, at + normal * min(d + 5, half), paint);
    }
  }

  static void _label(
    Canvas canvas,
    SplitLine line,
    Rect frame,
    double u,
    String text,
    Color color,
  ) {
    var normal = _normal(line);
    // Labels sit below a flat line and to the right of an upright one.
    if (normal.dy < 0 || (normal.dy == 0 && normal.dx < 0)) {
      normal = -normal;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: LSText.mono(
          14,
          color: color,
          weight: FontWeight.w700,
          spacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final center = line.at(frame, u) + normal * 24;
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(LinePainter oldDelegate) =>
      oldDelegate.question != question ||
      oldDelegate.outcome != outcome ||
      oldDelegate.aim != aim ||
      oldDelegate.finger != finger ||
      oldDelegate.margin != margin ||
      oldDelegate.reveal != reveal ||
      oldDelegate.loupe?.rect != loupe?.rect;
}

/// Where the slow-motion zoom sits on the card and what it shows: a
/// chamfered panel away from the line, magnifying the stretch round the
/// answer about x[zoom] (less when the gap wouldn't fit).
@immutable
class LoupeLayout {
  const LoupeLayout({
    required this.rect,
    required this.focus,
    required this.scale,
    required this.center,
    required this.halfSpan,
    required this.linePx,
  });

  static const height = 84.0;
  static const maxWidth = 260.0;
  static const minWidth = 120.0;
  static const zoom = 6.0;

  /// Room kept at the loupe's sides when fitting the gap.
  static const pad = 28.0;

  /// The loupe eases in (scale and fade) over this, from the slide's start.
  static const easeIn = Duration(milliseconds: 220);

  /// How far the loupe has eased in at reveal progress [t].
  static double appear(double t) {
    final share =
        LineSplitEngine.closeSlide.inMicroseconds / easeIn.inMicroseconds;
    return Curves.easeOutCubic.transform((t * share).clamp(0.0, 1.0));
  }

  /// The panel, in card coordinates.
  final Rect rect;

  /// The middle of the magnified stretch on the real line.
  final Offset focus;
  final double scale;

  /// The share of the line at the loupe's centre, and half the share it
  /// shows.
  final double center;
  final double halfSpan;

  /// The real line's length in pixels.
  final double linePx;

  double get from => center - halfSpan;
  double get to => center + halfSpan;

  /// The two corners of the loupe's edge that faces the line.
  (Offset, Offset) get nearCorners {
    final d = rect.center - focus;
    if (d.dy.abs() >= d.dx.abs()) {
      final y = d.dy > 0 ? rect.top : rect.bottom;
      return (Offset(rect.left, y), Offset(rect.right, y));
    }
    final x = d.dx > 0 ? rect.left : rect.right;
    return (Offset(x, rect.top), Offset(x, rect.bottom));
  }

  /// Null on a timeout or a card too small to hold it.
  static LoupeLayout? of(
    Size size,
    SplitQuestion question,
    SplitOutcome outcome,
    double margin,
  ) {
    final answer = outcome.answer;
    final frame = (Offset.zero & size).deflate(margin);
    if (answer == null || frame.isEmpty) {
      return null;
    }
    final line = question.line;
    final linePx = (line.end(frame) - line.start(frame)).distance;
    if (linePx <= 0) {
      return null;
    }
    const inset = 12.0;
    // Under the verdict chip, at the bottom, or beside an upright line.
    Rect band(double left, double top, double width) {
      final w = min(width, maxWidth);
      return Rect.fromLTWH(left + (width - w) / 2, top, w, height);
    }

    final full = size.width - inset * 2;
    final half = size.width / 2 - inset - 18;
    final middle = (size.height - height) / 2;
    final candidates =
        [
          band(inset, 54, full),
          band(inset, size.height - inset - height, full),
          band(inset, middle, half),
          band(size.width / 2 + 18, middle, half),
        ].where(
          (r) => r.width >= minWidth && r.top >= 0 && r.bottom <= size.height,
        );
    if (candidates.isEmpty) {
      return null;
    }

    double clearance(Rect r) {
      var nearest = double.infinity;
      for (var i = 0; i <= 40; i++) {
        final p = line.at(frame, i / 40);
        final dx = max(0.0, max(r.left - p.dx, p.dx - r.right));
        final dy = max(0.0, max(r.top - p.dy, p.dy - r.bottom));
        nearest = min(nearest, sqrt(dx * dx + dy * dy));
      }
      return nearest;
    }

    // The widest panel clear of the line; else the one furthest from it.
    final scored = [for (final r in candidates) (r, clearance(r))];
    final clear = scored.where((c) => c.$2 >= 12).toList()
      ..sort((a, b) {
        final byWidth = b.$1.width.compareTo(a.$1.width);
        return byWidth != 0 ? byWidth : b.$2.compareTo(a.$2);
      });
    final rect = clear.isNotEmpty
        ? clear.first.$1
        : (scored..sort((a, b) => b.$2.compareTo(a.$2))).first.$1;

    final truth = question.target.position;
    final gapPx = (answer - truth).abs() * linePx;
    final scale = min(
      zoom,
      (rect.width - 2 * pad) / max(gapPx, 1),
    ).clamp(1.0, zoom);
    final center = (answer + truth) / 2;
    return LoupeLayout(
      rect: rect,
      focus: line.at(frame, center),
      scale: scale,
      center: center,
      halfSpan: rect.width / 2 / (linePx * scale),
      linePx: linePx,
    );
  }
}

/// The slow-motion zoom: a chamfered panel showing the stretch round the
/// answer magnified, the true tick sliding from yours to the true point and
/// the gap filling in, with "Δ 1.6%". Reduce motion: shown at its final
/// state at once (the card's controller is already at 1).
class RevealLoupe extends StatelessWidget {
  const RevealLoupe({
    super.key,
    required this.layout,
    required this.question,
    required this.outcome,
    required this.reveal,
  });

  final LoupeLayout layout;
  final SplitQuestion question;
  final SplitOutcome outcome;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    final gap = LinePainter.gapColor(outcome);
    final zoom = layout.scale.toStringAsFixed(layout.scale < 2 ? 1 : 0);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) {
          final t = reveal.value;
          final appear = LoupeLayout.appear(t);
          final slide = Curves.easeInOutCubic.transform(t);
          return Opacity(
            opacity: appear,
            child: Transform.scale(
              scale: 0.85 + 0.15 * appear,
              child: ChamferBox(
                cut: Cut.md,
                color: LS.surface2,
                borderColor: gap.withValues(alpha: 0.6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: LoupePainter(
                        layout: layout,
                        question: question,
                        outcome: outcome,
                        slide: slide,
                        gap: gap,
                      ),
                    ),
                    Positioned(
                      top: 7,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Δ ${(outcome.error * slide).toStringAsFixed(1)}%',
                          style: LSText.mono(
                            13,
                            color: gap,
                            weight: FontWeight.w700,
                            spacing: 0.04,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 10,
                      child: MonoLabel('×$zoom', size: 10, color: LS.dim),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The inside of the loupe: the line straightened (0 end at the left), 1%
/// marks, whole numbers, your dashed tick and the sliding true tick.
class LoupePainter extends CustomPainter {
  LoupePainter({
    required this.layout,
    required this.question,
    required this.outcome,
    required this.slide,
    required this.gap,
  });

  final LoupeLayout layout;
  final SplitQuestion question;
  final SplitOutcome outcome;

  /// 0 at your tick, 1 at the true point.
  final double slide;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final answer = outcome.answer;
    if (answer == null) {
      return;
    }
    final y = size.height * 0.64;
    final perPx = layout.linePx * layout.scale;
    double x(double u) => size.width / 2 + (u - layout.center) * perPx;
    final from = max(0.0, layout.from);
    final to = min(1.0, layout.to);

    final minor = Paint()
      ..color = LS.dim.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var k = (from * 100).ceil(); k <= (to * 100).floor(); k++) {
      final h = k % 5 == 0 ? 7.0 : 4.0;
      final at = x(k / 100);
      canvas.drawLine(Offset(at, y + 9), Offset(at, y + 9 + h), minor);
    }
    canvas.drawLine(
      Offset(x(from), y),
      Offset(x(to), y),
      Paint()
        ..color = LS.text
        ..strokeWidth = 3,
    );
    final units = question.target.units;
    final whole = Paint()
      ..color = LS.text
      ..strokeWidth = 3;
    for (var k = 0; k <= units; k++) {
      final u = k / units;
      if (u >= from - 1e-9 && u <= to + 1e-9) {
        canvas.drawLine(Offset(x(u), y - 12), Offset(x(u), y + 12), whole);
      }
    }

    final truth = question.target.position;
    final moving = answer + (truth - answer) * slide;
    canvas.drawRect(
      Rect.fromLTRB(
        min(x(answer), x(moving)),
        y - 6,
        max(x(answer), x(moving)),
        y + 6,
      ),
      Paint()..color = gap.withValues(alpha: 0.5),
    );
    final dashed = Paint()
      ..color = LS.teal
      ..strokeWidth = 3;
    for (var d = -18.0; d < 18; d += 9) {
      canvas.drawLine(
        Offset(x(answer), y + d),
        Offset(x(answer), y + min(d + 5, 18)),
        dashed,
      );
    }
    canvas.drawLine(
      Offset(x(moving), y - 20),
      Offset(x(moving), y + 20),
      Paint()
        ..color = GameId.lineSplit.accent
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(LoupePainter oldDelegate) =>
      oldDelegate.slide != slide ||
      oldDelegate.layout != layout ||
      oldDelegate.outcome != outcome ||
      oldDelegate.question != question ||
      oldDelegate.gap != gap;
}

/// Drains over [limit], starting at limit ÷ the longest limit of the track;
/// freezes once [running] is false and snaps to the engine's [left] when it
/// stops or starts, so it stays in sync across a pause.
class _CountdownBar extends StatefulWidget {
  const _CountdownBar({
    super.key,
    required this.limit,
    required this.left,
    required this.running,
  });

  final Duration? limit;
  final Duration? left;
  final bool running;

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar>
    with SingleTickerProviderStateMixin {
  // Play-critical: reduce motion must not speed it up.
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.limit ?? Duration.zero,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _CountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final limit = widget.limit;
    if (limit == null) {
      _controller.stop();
      return;
    }
    if (widget.running) {
      if (!_controller.isAnimating && !_controller.isCompleted) {
        _snapToEngine(limit);
        _controller.forward();
      }
    } else {
      _controller.stop();
      _snapToEngine(limit);
    }
  }

  void _snapToEngine(Duration limit) {
    final left = widget.left;
    if (left != null && limit > Duration.zero) {
      _controller.value = (1 - left.inMicroseconds / limit.inMicroseconds)
          .clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limit = widget.limit;
    if (limit == null) {
      return const SizedBox(height: 4);
    }
    final start =
        limit.inMilliseconds / LineSplitEngine.maxTimeLimit.inMilliseconds;
    return SizedBox(
      height: 4,
      child: ColoredBox(
        color: LS.surface2,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (start * (1 - _controller.value)).clamp(0.0, 1.0),
            child: ColoredBox(color: GameId.lineSplit.accent),
          ),
        ),
      ),
    );
  }
}
