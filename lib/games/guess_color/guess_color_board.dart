import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import 'guess_color_engine.dart';

/// Label colors on each fill: dark text on yellow and green; light text on
/// red and blue, over a dark chip so it keeps ≥ 4.5:1 (checked in tests).
@visibleForTesting
({Color text, Color? chip}) labelColorsOn(InkColor fill) => switch (fill) {
  InkColor.yellow || InkColor.green => (text: LS.bg, chip: null),
  InkColor.red ||
  InkColor.blue => (text: LS.text, chip: LS.bg.withValues(alpha: 0.6)),
};

/// The COLOR | TEXT switch on top, the item card filling the middle, the
/// countdown bar, then the 2×2 answers. Kept apart from the round host so
/// tests can pump it on its own.
class GuessColorBoard extends StatelessWidget {
  const GuessColorBoard({super.key, required this.engine});

  final GuessColorEngine engine;

  @override
  Widget build(BuildContext context) {
    final item = engine.item;
    // Reduce motion: no pulse or shake, instant swaps and flips.
    final calm = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RuleSwitch(item: item, calm: calm),
          const SizedBox(height: 14),
          Expanded(
            flex: 3,
            child: ChamferBox(
              cut: Cut.lg,
              color: LS.well,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Transform.rotate(
                  angle: item.rotationDegrees * pi / 180,
                  child: _Distract(
                    key: ObjectKey(item),
                    item: item,
                    active: engine.isPlaying && !calm,
                    child: _ItemView(item),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CountdownBar(
            key: ValueKey(engine.wordStartedAt),
            limit: engine.timeLimit,
            running: !engine.locked,
          ),
          const SizedBox(height: 14),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var col = 0; col < 2; col++) ...[
                          if (col > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _AnswerButton(
                              engine: engine,
                              slot: row * 2 + col,
                              calm: calm,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Display-only two-segment control. The lit side slides across on a rule
/// change and pulses once.
class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({required this.item, required this.calm});

  final GuessItem item;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final accent = GameId.guessColor.accent;
    final onColor = item.rule == GuessRule.color;
    final flip = item.ruleChanged && !calm;
    return Semantics(
      label: onColor ? 'Rule: tap the color' : 'Rule: tap the text',
      excludeSemantics: true,
      child: ChamferBox(
        cut: Cut.sm,
        height: 52,
        padding: const EdgeInsets.all(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              alignment: onColor ? Alignment.centerLeft : Alignment.centerRight,
              duration: calm
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                // A fresh key per item restarts the one-off pulse.
                child: TweenAnimationBuilder<double>(
                  key: ObjectKey(item),
                  tween: Tween(begin: flip ? 0 : 1, end: 1),
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
                for (final rule in GuessRule.values)
                  Expanded(
                    child: _RuleSide(
                      rule: rule,
                      color: rule == item.rule ? accent : LS.dim,
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

  final GuessRule rule;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isColor = rule == GuessRule.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isColor)
          Icon(Icons.water_drop_outlined, size: 16, color: color)
        else
          Text('Aa', style: LSText.display(14, color: color)),
        const SizedBox(width: 8),
        DisplayText(isColor ? 'Color' : 'Text', size: 17, color: color),
      ],
    );
  }
}

/// Pulse and shake for the item (from word 41), looping while [active].
class _Distract extends StatefulWidget {
  const _Distract({
    super.key,
    required this.item,
    required this.active,
    required this.child,
  });

  final GuessItem item;
  final bool active;
  final Widget child;

  @override
  State<_Distract> createState() => _DistractState();
}

class _DistractState extends State<_Distract>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool get _moving => widget.active && (widget.item.pulse || widget.item.shake);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Distract oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!_moving) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final scale = widget.item.pulse ? 1 + 0.06 * sin(2 * pi * t) : 1.0;
        // A short, fading shake at the start of each cycle.
        final burst = t < 0.3 ? 1 - t / 0.3 : 0.0;
        final dx = widget.item.shake ? 6 * burst * sin(t / 0.3 * 6 * pi) : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView(this.item);

  final GuessItem item;

  @override
  Widget build(BuildContext context) {
    final shape = item.shape;
    if (shape != null) {
      return Semantics(
        label: shape.name,
        child: SizedBox.square(
          dimension: 120,
          child: CustomPaint(painter: _ShapePainter(shape, item.ink.color)),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DisplayText(item.text!, size: 88, color: item.ink.color),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter(this.shape, this.color);

  final GuessShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    switch (shape) {
      case GuessShape.circle:
        canvas.drawCircle(center, r * 0.9, paint);
      case GuessShape.square:
        canvas.drawRect(
          Rect.fromCircle(center: center, radius: r * 0.8),
          paint,
        );
      case GuessShape.triangle:
        canvas.drawPath(_polygon(center, [r, r, r]), paint);
      case GuessShape.star:
        final radii = [for (var i = 0; i < 10; i++) i.isEven ? r : r * 0.45];
        canvas.drawPath(_polygon(center, radii), paint);
    }
  }

  /// Points evenly spaced around [center], the first straight up.
  static Path _polygon(Offset center, List<double> radii) => Path()
    ..addPolygon([
      for (var i = 0; i < radii.length; i++)
        center +
            Offset.fromDirection(-pi / 2 + i * 2 * pi / radii.length, radii[i]),
    ], true);

  @override
  bool shouldRepaint(_ShapePainter oldWidget) =>
      oldWidget.shape != shape || oldWidget.color != color;
}

/// Drains over [limit]. It starts at limit ÷ 3 s of the track, so the
/// shrinking limit shows without a number; freezes once [running] is false.
class _CountdownBar extends StatefulWidget {
  const _CountdownBar({super.key, required this.limit, required this.running});

  final Duration? limit;
  final bool running;

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.limit ?? Duration.zero,
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
    if (widget.limit != null && widget.running) {
      if (!_controller.isAnimating && !_controller.isCompleted) {
        _controller.forward();
      }
    } else {
      _controller.stop();
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
        limit.inMilliseconds / GuessColorEngine.maxTimeLimit.inMilliseconds;
    return SizedBox(
      height: 4,
      child: ColoredBox(
        color: LS.surface2,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (start * (1 - _controller.value)).clamp(0.0, 1.0),
            child: ColoredBox(color: GameId.guessColor.accent),
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.engine,
    required this.slot,
    required this.calm,
  });

  final GuessColorEngine engine;
  final int slot;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final button = engine.item.buttons[slot];
    final fill = button.fill;
    final reveal = engine.picked != null || engine.timedOut;
    final isAnswer = fill == engine.item.target;
    // After a tap or timeout: the answer is outlined teal, a wrong pick
    // coral, and the rest fade.
    final Color? state = !reveal
        ? null
        : isAnswer
        ? LS.teal
        : engine.picked == fill
        ? LS.coral
        : null;
    final motion = calm ? Duration.zero : const Duration(milliseconds: 180);
    final colors = labelColorsOn(fill);
    final chip = colors.chip;
    final label = DisplayText(button.label.label, size: 22, color: colors.text);

    return AnimatedOpacity(
      opacity: reveal && state == null ? 0.3 : 1,
      duration: motion,
      child: ChamferBox(
        color: LS.bg,
        borderColor: state,
        padding: const EdgeInsets.all(4),
        // Scrambles morph each slot's fill instead of jumping.
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: fill.color),
          duration: motion,
          builder: (context, color, child) => ChamferBox(
            color: color ?? fill.color,
            borderColor: null,
            onTap: engine.locked ? null : () => engine.pick(fill),
            child: child!,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: chip == null
                        ? label
                        : ColoredBox(
                            color: chip,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: label,
                            ),
                          ),
                  ),
                ),
              ),
              if (state != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: SizedBox.square(
                    dimension: 28,
                    child: ColoredBox(
                      color: LS.bg.withValues(alpha: 0.6),
                      child: Icon(
                        isAnswer ? Icons.check : Icons.close,
                        size: 18,
                        color: state,
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
