import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// A horizontal degree tape (0–360) under a fixed centre needle: ticks
/// every 5°, labels every 30°. Display-only when [onChanged] is null (after
/// a lock, when the board slides it to the true value).
///
/// Dragging keeps a fractional value and paints it smoothly; [onChanged]
/// gets the rounded whole degree whenever that changes, so the readout and
/// Lock always use whole degrees. A slow drag is exact (1° per
/// [pixelsPerDegree] px); a fast one speeds up smoothly to [maxGain]×. A
/// release flings with friction (capped at [flingCap] °/s), then settles on
/// the nearest whole degree. A new touch stops the fling. Reduce motion
/// snaps at once instead of flinging.
class DegreeTape extends StatefulWidget {
  const DegreeTape({
    super.key,
    required this.value,
    this.onChanged,
    this.height = 54,
  });

  /// Pixels per degree on the strip (and per degree of a slow drag).
  static const pixelsPerDegree = 6.0;

  /// Drag speeds (px/s) where the gain starts rising and where it caps.
  static const slowSpeed = 250.0;
  static const fastSpeed = 1500.0;
  static const maxGain = 3.0;

  /// The drag-speed smoothing window.
  static const speedWindow = Duration(milliseconds: 65);

  /// Releases slower than this (px/s) just snap to the nearest degree.
  static const flingMinSpeed = 150.0;

  /// The fastest fling, in degrees per second.
  static const flingCap = 220.0;

  /// The fling's friction: the share of its velocity left after a second.
  static const friction = 0.05;

  /// The farthest a fling can travel, in degrees.
  static double get maxFling => flingCap / -log(friction);

  /// The soft landing on a whole degree.
  static const settle = Duration(milliseconds: 150);

  /// At most one tick haptic per this, during fast moves.
  static const hapticGap = Duration(milliseconds: 40);

  /// Degrees per pixel multiplier for a drag at [speed] px/s: 1 up to
  /// [slowSpeed], easing (smoothstep) to [maxGain] at [fastSpeed].
  static double gainFor(double speed) {
    final x = ((speed - slowSpeed) / (fastSpeed - slowSpeed)).clamp(0.0, 1.0);
    return 1 + (maxGain - 1) * x * x * (3 - 2 * x);
  }

  final double value;
  final ValueChanged<int>? onChanged;
  final double height;

  @override
  State<DegreeTape> createState() => _DegreeTapeState();
}

class _DegreeTapeState extends State<DegreeTape>
    with SingleTickerProviderStateMixin {
  /// Drives the fling and the settle, in degrees.
  late final AnimationController _motion;

  /// The fractional value while the player drags, flings or settles; null
  /// otherwise (the tape shows [DegreeTape.value]).
  double? _live;
  bool _dragging = false;
  bool _settling = false;

  /// A finger is on the tape (it stopped any fling).
  bool _held = false;

  /// Smoothed drag speed (px/s) and the last update's time stamp.
  double _speed = 0;
  Duration? _lastStamp;

  int? _sent;
  int? _lastMark;
  final _haptics = Stopwatch()..start();
  Duration _lastHaptic = -DegreeTape.hapticGap;

  bool get _enabled => widget.onChanged != null;
  double get _shown => _live ?? widget.value;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(vsync: this)
      ..addListener(_onMotion);
  }

  @override
  void didUpdateWidget(covariant DegreeTape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _live != null) {
      // Locked mid-move: the last whole degree sent is the answer.
      _motion.stop();
      _live = null;
      _dragging = false;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _set(num degrees) =>
      widget.onChanged?.call(degrees.round().clamp(0, 360));

  /// Moves the live value, sends whole degrees and ticks on 5° marks.
  void _move(double degrees) {
    final value = degrees.clamp(0.0, 360.0);
    setState(() => _live = value);
    final whole = value.round();
    if (whole != _sent) {
      _sent = whole;
      _set(whole);
    }
    final mark = (value / 5).floor();
    if (_lastMark != null && mark != _lastMark) {
      final now = _haptics.elapsed;
      if (now - _lastHaptic >= DegreeTape.hapticGap) {
        _lastHaptic = now;
        HapticFeedback.selectionClick();
      }
    }
    _lastMark = mark;
  }

  void _begin(double from) {
    _live = from;
    _sent = from.round();
    _lastMark = (from / 5).floor();
  }

  void _onMotion() {
    if (_live == null) {
      return;
    }
    final value = _motion.value;
    _move(value);
    if (!_settling && (value <= 0 || value >= 360)) {
      _settleOn(value);
    }
  }

  /// A touch stops any fling at once.
  void _onDown(PointerDownEvent _) {
    _held = true;
    _settling = false;
    _motion.stop();
  }

  /// A tap that stopped a fling lands on the nearest degree.
  void _onUp(PointerUpEvent _) {
    _held = false;
    if (!_dragging && _live != null && !_motion.isAnimating) {
      _settleOn(_live!);
    }
  }

  void _onDragStart(DragStartDetails details) {
    _settling = false;
    _motion.stop();
    _dragging = true;
    _speed = 0;
    _lastStamp = details.sourceTimeStamp;
    _begin(_live ?? widget.value);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx;
    final stamp = details.sourceTimeStamp;
    final last = _lastStamp;
    if (stamp != null && last != null && stamp > last) {
      final dt = (stamp - last).inMicroseconds / 1e6;
      final window = DegreeTape.speedWindow.inMicroseconds / 1e6;
      final alpha = 1 - exp(-dt / window);
      _speed += alpha * (dx.abs() / dt - _speed);
    }
    if (stamp != null) {
      _lastStamp = stamp;
    }
    final gain = DegreeTape.gainFor(_speed);
    _move(_live! - dx / DegreeTape.pixelsPerDegree * gain);
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final live = _live;
    if (live == null) {
      return;
    }
    final px = details.velocity.pixelsPerSecond.dx;
    if (px.abs() < DegreeTape.flingMinSpeed ||
        MediaQuery.disableAnimationsOf(context)) {
      _snap(live);
      return;
    }
    final degrees =
        (-px / DegreeTape.pixelsPerDegree * DegreeTape.gainFor(px.abs())).clamp(
          -DegreeTape.flingCap,
          DegreeTape.flingCap,
        );
    _settling = false;
    _motion.value = live;
    _motion
        .animateWith(
          FrictionSimulation(
            DegreeTape.friction,
            live,
            degrees,
            tolerance: const Tolerance(velocity: 2),
          ),
        )
        .whenCompleteOrCancel(() {
          // Ended on its own; a touch-stop settles on pointer up.
          if (mounted && !_settling && !_held && _live != null) {
            _settleOn(_motion.value);
          }
        });
  }

  /// Lands softly on the nearest whole degree (at once under reduce
  /// motion).
  void _settleOn(double from) {
    final target = from.round().clamp(0, 360).toDouble();
    if (MediaQuery.disableAnimationsOf(context) ||
        (target - from).abs() < 1e-3) {
      _snap(from);
      return;
    }
    _settling = true;
    _motion.stop();
    _motion.value = from;
    _motion
        .animateTo(
          target,
          duration: DegreeTape.settle,
          curve: Curves.easeOutCubic,
        )
        .whenCompleteOrCancel(() {
          if (mounted && _settling) {
            _settling = false;
            _snap(target);
          }
        });
  }

  void _snap(double from) {
    _motion.stop();
    _move(from.roundToDouble());
    setState(() => _live = null);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final value = _shown.round();
    return Semantics(
      slider: true,
      label: 'Your guess',
      value: '$value degrees',
      increasedValue: '${min(360, value + 1)} degrees',
      decreasedValue: '${max(0, value - 1)} degrees',
      onIncrease: enabled ? () => _set(value + 1) : null,
      onDecrease: enabled ? () => _set(value - 1) : null,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: enabled ? _onDown : null,
        onPointerUp: enabled ? _onUp : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Count the whole drag, slop included, so slow drags are exact.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: enabled ? _onDragStart : null,
          onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
          onHorizontalDragEnd: enabled ? _onDragEnd : null,
          child: SizedBox(
            height: widget.height,
            child: CustomPaint(
              painter: _TapePainter(_shown),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final line = Paint()..color = LS.line;
    canvas
      ..clipRect(rect)
      ..drawRect(rect, Paint()..color = LS.surface)
      ..drawRect(Rect.fromLTWH(0, 0, size.width, 1), line)
      ..drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), line);

    const px = DegreeTape.pixelsPerDegree;
    final mid = size.width / 2;
    final span = (mid / px).ceil() + 5;
    final first = max(0, ((value - span) / 5).floor() * 5);
    final last = min(360, value + span);
    for (var d = first; d <= last; d += 5) {
      final x = mid + (d - value) * px;
      final major = d % 30 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, major ? 22 : 14),
        Paint()
          ..color = major ? LS.text : LS.muted
          ..strokeWidth = major ? 2 : 1,
      );
      if (major) {
        final text = TextPainter(
          text: TextSpan(text: '$d', style: LSText.mono(11, spacing: 0)),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(x - text.width / 2, size.height - 20));
        text.dispose();
      }
    }

    // The fixed centre needle, with a notch on top.
    final gold = Paint()..color = LS.gold;
    canvas
      ..drawRect(Rect.fromLTWH(mid - 1, 0, 2, size.height), gold)
      ..drawPath(
        Path()
          ..moveTo(mid - 6, 0)
          ..lineTo(mid + 6, 0)
          ..lineTo(mid, 7)
          ..close(),
        gold,
      );
  }

  @override
  bool shouldRepaint(_TapePainter oldDelegate) => oldDelegate.value != value;
}
