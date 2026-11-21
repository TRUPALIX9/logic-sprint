import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import '../../ui/reveal.dart';
import 'angle_painter.dart';
import 'angle_sense_engine.dart';
import 'angle_shields.dart';
import 'degree_tape.dart';

/// The READ | DRAW switch, the status row (question, window), the square
/// card (with the shields in its corner), then the tape or the DRAW target with −1 / Lock / +1. Kept
/// apart from the round host so tests can pump it on its own.
class AngleSenseBoard extends StatefulWidget {
  const AngleSenseBoard({super.key, required this.engine});

  final AngleSenseEngine engine;

  @override
  State<AngleSenseBoard> createState() => _AngleSenseBoardState();
}

class _AngleSenseBoardState extends State<AngleSenseBoard>
    with SingleTickerProviderStateMixin {
  /// The reveal: the gold arm and the tape sweep from the answer to the
  /// truth, over the outcome's tier ([AngleSenseEngine.sweepFor]). Cosmetic
  /// (the engine times the run), so reduce motion skips to the end.
  late final _sweep = AnimationController(
    vsync: this,
    duration: AngleSenseEngine.revealDuration,
  );
  AngleOutcome? _shown;
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngine);
    _syncSweep();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant AngleSenseBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngine);
      widget.engine.addListener(_onEngine);
      _syncSweep();
    }
  }

  void _onEngine() {
    if (widget.engine.outcome != _shown) {
      _syncSweep();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _syncSweep() {
    final outcome = widget.engine.outcome;
    _shown = outcome;
    if (outcome == null) {
      _sweep.value = 0;
      return;
    }
    _sweep.duration = AngleSenseEngine.sweepFor(outcome.tier);
    if (_calm) {
      _sweep.value = 1;
    } else {
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngine);
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final calm = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RuleSwitch(
            rule: engine.rule,
            pulse: engine.ruleChanged && !calm,
            question: engine.question,
            calm: calm,
          ),
          const SizedBox(height: 10),
          _StatusRow(engine: engine),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Center(
                child: SizedBox.square(
                  dimension: min(box.maxWidth, box.maxHeight),
                  child: _Card(engine: engine, sweep: _sweep),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Controls(engine: engine, sweep: _sweep),
        ],
      ),
    );
  }
}

/// Display-only two-segment control. The lit side slides across on a rule
/// change and pulses once.
class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({
    required this.rule,
    required this.pulse,
    required this.question,
    required this.calm,
  });

  final AngleRule rule;
  final bool pulse;

  /// Keys the one-off pulse to the question that changed the rule.
  final AngleQuestion question;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final accent = GameId.angleSense.accent;
    final reading = rule == AngleRule.read;
    return Semantics(
      label: reading ? 'Rule: read the angle' : 'Rule: draw the angle',
      excludeSemantics: true,
      child: ChamferBox(
        cut: Cut.sm,
        height: 46,
        padding: const EdgeInsets.all(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              alignment: reading ? Alignment.centerLeft : Alignment.centerRight,
              duration: calm
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: TweenAnimationBuilder<double>(
                  key: ObjectKey(question),
                  tween: Tween(begin: pulse ? 0 : 1, end: 1),
                  duration: const Duration(milliseconds: 420),
                  builder: (context, t, child) => Transform.scale(
                    scale: 1 + 0.08 * sin(pi * t),
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: chamfer(Cut.sm, border: accent),
                      color: accent.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final side in AngleRule.values)
                  Expanded(
                    child: _RuleSide(
                      rule: side,
                      color: side == rule ? accent : LS.dim,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSide extends StatelessWidget {
  const _RuleSide({required this.rule, required this.color});

  final AngleRule rule;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reading = rule == AngleRule.read;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          reading ? Icons.visibility_outlined : Icons.north_east,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        DisplayText(reading ? 'Read' : 'Draw', size: 16, color: color),
      ],
    );
  }
}

/// The question number and the window.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.engine});

  final AngleSenseEngine engine;

  @override
  Widget build(BuildContext context) {
    final number = engine.number.toString().padLeft(2, '0');
    final where = engine.isCompassRound
        ? 'Q$number · Compass round'
        : '${engine.difficulty.label} · Q$number';
    return Row(
      children: [
        Expanded(child: MonoLabel(where)),
        Text.rich(
          TextSpan(
            text: 'WINDOW ',
            children: [
              TextSpan(
                text: '±${engine.window}°',
                style: LSText.mono(11, color: LS.gold, weight: FontWeight.w700),
              ),
            ],
          ),
          style: LSText.mono(11),
        ),
      ],
    );
  }
}

/// Where in the sweep (0–1) the verdict shows: as a perfect answer's arms
/// merge, else when the sweep lands. A lost shield breaks then too.
double _verdictAt(AngleOutcome outcome) =>
    outcome.tier == RevealTier.perfect ? perfectMerge : 1.0;

/// The square card: the scene, DRAW aiming, the verdict chip and the
/// countdown bar.
class _Card extends StatelessWidget {
  const _Card({required this.engine, required this.sweep});

  final AngleSenseEngine engine;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final question = engine.question;
    final drawing = question.rule == AngleRule.draw && !engine.locked;
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide;
        void aimAt(Offset local) {
          final v = question.vertex * side;
          final d = local - v;
          if (d.distance < 4) {
            return;
          }
          final screen = atan2(-d.dy, d.dx) * 180 / pi;
          engine.aim(question.dir * (screen - question.base));
        }

        return ChamferBox(
          cut: Cut.lg,
          color: LS.well,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: question.rule == AngleRule.draw
                    ? _drawPrompt(question)
                    : 'Angle to read',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: drawing ? (d) => aimAt(d.localPosition) : null,
                  onPanUpdate: drawing ? (d) => aimAt(d.localPosition) : null,
                  // Hidden during the get-ready countdown; each new
                  // question eases in.
                  child: Reveal(
                    revealKey: question,
                    hidden: engine.isResuming,
                    child: AnimatedBuilder(
                      animation: sweep,
                      builder: (context, _) => CustomPaint(
                        size: Size.infinite,
                        painter: AnglePainter(
                          question: question,
                          drawGuess: engine.drawGuess,
                          outcome: engine.outcome,
                          sweep: sweep.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (engine.outcome case final shown?
                  when shown.tier == RevealTier.close)
                _Loupe.positioned(
                  question: question,
                  outcome: shown,
                  side: side,
                  sweep: sweep,
                ),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: _Verdict(outcome: engine.outcome, sweep: sweep),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: AnimatedBuilder(
                  animation: sweep,
                  builder: (context, _) {
                    // A lost shield stays up until its verdict shows.
                    final shown = engine.outcome;
                    final pending =
                        shown != null &&
                        !shown.grade.isHit &&
                        sweep.value < _verdictAt(shown);
                    return AngleShields(
                      left: engine.strikesLeft + (pending ? 1 : 0),
                      total: AngleSenseEngine.maxStrikes,
                      waiting: engine.isResuming,
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CountdownBar(
                  key: ValueKey(engine.questionStartedAt),
                  limit: engine.timeLimit,
                  left: engine.timeLeft,
                  running: !engine.locked,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _drawPrompt(AngleQuestion question) => switch (question.kind) {
    AngleKind.compassRound =>
      'Compass: drag the needle to ${question.heading.toLowerCase()}',
    AngleKind.drawClock =>
      'Clock face: drag the hand to ${question.answer} degrees clockwise from 12',
    _ => 'Drag the second arm to ${question.answer} degrees from the base arm',
  };
}

/// The close reveal's zoom: a chamfered panel in the card corner farthest
/// from the arms, showing the tips about ×5 while the gold arm crawls across
/// the gap in slow motion, with the gap in degrees. It eases in (scale and
/// fade) over its first [_intro]; reduce motion shows it at once, static.
class _Loupe extends StatelessWidget {
  const _Loupe({
    required this.question,
    required this.outcome,
    required this.side,
    required this.sweep,
    required this.alignment,
  });

  final AngleQuestion question;
  final AngleOutcome outcome;
  final double side;
  final Animation<double> sweep;

  /// Which corner it sits in; it scales in from there.
  final Alignment alignment;

  static const _intro = Duration(milliseconds: 220);
  static const _size = 0.4;

  /// Placed in the corner farthest from the arms. Top corners sit below
  /// the verdict chip.
  static Widget positioned({
    required AngleQuestion question,
    required AngleOutcome outcome,
    required double side,
    required Animation<double> sweep,
  }) {
    final corner = cornerFor(question, outcome);
    final top = corner.y < 0;
    final left = corner.x < 0;
    final edge = side * 0.04;
    return Positioned(
      left: left ? edge : null,
      right: left ? null : edge,
      top: top ? side * 0.15 : null,
      bottom: top ? null : edge + 6,
      width: side * _size,
      height: side * _size,
      child: _Loupe(
        question: question,
        outcome: outcome,
        side: side,
        sweep: sweep,
        alignment: corner,
      ),
    );
  }

  /// The corner whose loupe centre is farthest from the base arm, the true
  /// arm and the answer's arm (all from the vertex, in card units).
  static Alignment cornerFor(AngleQuestion q, AngleOutcome outcome) {
    final arms = [
      q.point(q.base, q.armLength),
      q.point(q.armAt(q.answer), q.secondArmLength),
      if (outcome.guess != null)
        q.point(q.armAt(outcome.guess!), q.secondArmLength),
    ];
    double clearance(Offset p) {
      var best = double.infinity;
      for (final end in arms) {
        best = min(best, _toSegment(p, q.vertex, end));
      }
      return best;
    }

    const lo = 0.04 + _size / 2;
    const hi = 1 - lo;
    const corners = [
      (Alignment.bottomLeft, Offset(lo, hi)),
      (Alignment.bottomRight, Offset(hi, hi)),
      (Alignment.topLeft, Offset(lo, 0.15 + _size / 2)),
      (Alignment.topRight, Offset(hi, 0.15 + _size / 2)),
    ];
    var pick = Alignment.bottomLeft;
    var far = -1.0;
    for (final (corner, centre) in corners) {
      final d = clearance(centre);
      if (d > far + 1e-9) {
        far = d;
        pick = corner;
      }
    }
    return pick;
  }

  static double _toSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.distanceSquared;
    final t = length2 == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final gap = gapColor(outcome);
    final degrees = outcome.error?.abs() ?? 0;
    final introShare =
        _intro.inMicroseconds / AngleSenseEngine.closeSweep.inMicroseconds;
    return Semantics(
      key: const ValueKey('angle-loupe'),
      label: 'Zoomed in: off by $degrees degrees',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: sweep,
        builder: (context, child) {
          final intro = Curves.easeOutCubic.transform(
            (sweep.value / introShare).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: intro,
            child: Transform.scale(
              scale: 0.85 + 0.15 * intro,
              alignment: alignment,
              child: child,
            ),
          );
        },
        child: ChamferBox(
          cut: Cut.md,
          color: LS.well,
          borderColor: gap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: sweep,
                builder: (context, _) => CustomPaint(
                  painter: AngleLoupePainter(
                    question: question,
                    outcome: outcome,
                    cardSide: side,
                    sweep: sweep.value,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(
                  'Δ $degrees°',
                  style: LSText.mono(
                    13,
                    color: gap,
                    weight: FontWeight.w700,
                    spacing: 0,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 6,
                child: Text(
                  '×${AngleLoupePainter.maxZoom.round()}',
                  style: LSText.mono(10, color: LS.muted, spacing: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "PERFECT 0°", "SHARP −1°", "HIT +2°", "SO CLOSE +10°", "MISS +14°" or
/// "TIME", once the sweep lands (a perfect answer's as the arms merge).
class _Verdict extends StatelessWidget {
  const _Verdict({required this.outcome, required this.sweep});

  final AngleOutcome? outcome;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sweep,
      builder: (context, _) {
        final shown = outcome;
        if (shown == null || sweep.value < _verdictAt(shown)) {
          return const SizedBox.shrink();
        }
        final color = switch (shown.grade) {
          AngleGrade.bullseye => LS.gold,
          AngleGrade.sharp => sharpTint,
          AngleGrade.hit => LS.teal,
          AngleGrade.miss || AngleGrade.time => LS.coral,
        };
        return Semantics(
          liveRegion: true,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: chamfer(
                Cut.sm,
                border: shown.tier == RevealTier.normal ? null : color,
              ),
              color: Color.alphaBlend(color.withValues(alpha: 0.14), LS.bg),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(shown.chip, style: LSText.display(24, color: color)),
            ),
          ),
        );
      },
    );
  }
}

/// Drains over [limit]; freezes once [running] is false (a lock, the run
/// going down, or a pause) and snaps to the engine's [left] whenever it
/// stops or starts, so it stays in sync across a pause. It stands for a
/// play timer, so reduce motion doesn't shorten it.
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
    if (widget.limit == null) {
      return const SizedBox(height: 3);
    }
    return SizedBox(
      height: 3,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (1 - _controller.value).clamp(0.0, 1.0),
          child: ColoredBox(color: GameId.angleSense.accent),
        ),
      ),
    );
  }
}

/// READ: readout, tape, then −1 / Lock / +1. DRAW: the target number and a
/// hint in the same space (no live readout), then the same buttons. After a
/// lock both show the tape sliding to the true value.
class _Controls extends StatelessWidget {
  const _Controls({required this.engine, required this.sweep});

  final AngleSenseEngine engine;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final question = engine.question;
    final outcome = engine.outcome;
    final aiming = question.rule == AngleRule.draw && outcome == null;
    final hidden = engine.isResuming;
    final canNudge =
        !engine.locked &&
        (question.rule == AngleRule.read || engine.drawGuess != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: aiming
              ? Center(
                  child: Reveal(
                    revealKey: question,
                    hidden: hidden,
                    child: FittedBox(
                      child: Text(
                        question.kind == AngleKind.compassRound
                            ? question.heading
                            : '${question.answer}°',
                        style: LSText.mono(
                          34,
                          color: LS.gold,
                          weight: FontWeight.w700,
                          spacing: 0,
                        ),
                      ),
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: sweep,
                  builder: (context, _) => Center(
                    child: ExcludeSemantics(
                      child: Text.rich(
                        TextSpan(
                          text: '${_tapeValue(engine, sweep.value).round()}',
                          children: [
                            TextSpan(
                              text: '°',
                              style: LSText.mono(20, spacing: 0),
                            ),
                          ],
                        ),
                        style: LSText.mono(
                          40,
                          color: LS.text,
                          weight: FontWeight.w700,
                          spacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: aiming
              ? ChamferBox(
                  cut: Cut.sm,
                  child: Center(
                    child: MonoLabel(
                      question.kind == AngleKind.compassRound
                          ? 'Drag the needle on the dial · Lock'
                          : question.kind == AngleKind.drawClock
                          ? 'Drag the hand, clockwise from 12 · Lock'
                          : 'Drag on the card to aim · Lock',
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: sweep,
                  builder: (context, _) => DegreeTape(
                    value: _tapeValue(engine, sweep.value),
                    onChanged: engine.locked ? null : engine.setGuess,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PadButton(
                width: 60,
                label: '−1',
                semanticLabel: 'Minus one degree',
                repeat: true,
                onTap: canNudge ? () => engine.nudge(-1) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PadButton(
                  label: 'Lock',
                  semanticLabel: 'Lock',
                  primary: true,
                  onTap: engine.canLock ? engine.lock : null,
                ),
              ),
              const SizedBox(width: 8),
              _PadButton(
                width: 60,
                label: '+1',
                semanticLabel: 'Plus one degree',
                repeat: true,
                onTap: canNudge ? () => engine.nudge(1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The tape's value: the guess, or during the reveal on its way from the
  /// player's answer to the truth.
  static double _tapeValue(AngleSenseEngine engine, double sweep) {
    final outcome = engine.outcome;
    if (outcome == null) {
      return engine.guess.toDouble();
    }
    final truth = engine.question.answer;
    final from = outcome.guess ?? truth;
    final delta = -AngleSenseEngine.signedError(from, truth);
    final now = from + delta * revealArm(outcome.tier, sweep);
    // The tape runs 0–360: land on the truth itself, not on its wrap.
    return revealArm(outcome.tier, sweep) >= 1
        ? truth.toDouble()
        : AngleSenseEngine.norm(now);
  }
}

/// A pad button. With [repeat], a long press keeps firing [onTap]: about
/// 8 a second, rising to about 20 a second after [rampAfter].
class _PadButton extends StatefulWidget {
  const _PadButton({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.width,
    this.primary = false,
    this.repeat = false,
  });

  static const slowRepeat = Duration(milliseconds: 125);
  static const fastRepeat = Duration(milliseconds: 50);
  static const rampAfter = Duration(milliseconds: 600);

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double? width;
  final bool primary;
  final bool repeat;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  Timer? _timer;
  Duration _held = Duration.zero;

  void _start() {
    _stop();
    _held = Duration.zero;
    widget.onTap?.call();
    _schedule();
  }

  void _schedule() {
    final gap = _held >= _PadButton.rampAfter
        ? _PadButton.fastRepeat
        : _PadButton.slowRepeat;
    _timer = Timer(gap, () {
      final tap = widget.onTap;
      if (!mounted || tap == null) {
        _timer = null;
        return;
      }
      _held += gap;
      tap();
      _schedule();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final primary = widget.primary;
    final label = widget.label;
    final style = primary
        ? LSText.display(18, color: LS.bg)
        : LSText.mono(16, color: LS.text, spacing: 0);
    Widget button = ChamferBox(
      cut: Cut.sm,
      width: widget.width,
      color: primary ? LS.gold : LS.surface2,
      borderColor: primary ? null : LS.line,
      onTap: widget.onTap,
      child: Center(
        child: Text(primary ? label.toUpperCase() : label, style: style),
      ),
    );
    if (widget.repeat && enabled) {
      button = GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _stop,
        child: button,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Opacity(opacity: enabled ? 1 : 0.4, child: button),
    );
  }
}
