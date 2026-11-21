import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// The run's shields in the card's top-right corner: solid gold while held,
/// a dim outline once lost. Losing one breaks it (flash, split, shards);
/// a revive pops it back in once [waiting] (the get-ready countdown) ends.
class AngleShields extends StatelessWidget {
  const AngleShields({
    super.key,
    required this.left,
    required this.total,
    required this.waiting,
    this.size = 19,
  });

  /// Shields held, as shown (the board holds a lost one until its verdict).
  final int left;
  final int total;

  /// True during the get-ready countdown; a restored shield waits for it.
  final bool waiting;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Shields: $left of $total',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            AngleShield(
              key: ValueKey('shield-$i'),
              full: i < left,
              waiting: waiting,
              size: size,
            ),
          ],
        ],
      ),
    );
  }
}

/// One shield. Going from [full] to not plays [breakDuration] (with one
/// medium haptic); coming back plays [popDuration] once [waiting] is false.
/// Reduce motion switches states at once.
class AngleShield extends StatefulWidget {
  const AngleShield({
    super.key,
    required this.full,
    required this.waiting,
    this.size = 19,
  });

  static const breakDuration = Duration(milliseconds: 450);
  static const popDuration = Duration(milliseconds: 250);

  final bool full;
  final bool waiting;
  final double size;

  @override
  State<AngleShield> createState() => _AngleShieldState();
}

class _AngleShieldState extends State<AngleShield>
    with TickerProviderStateMixin {
  late final _break = AnimationController(
    vsync: this,
    duration: AngleShield.breakDuration,
    value: 1,
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: AngleShield.popDuration,
    value: 1,
  );

  /// Restored during the countdown; pops in when it ends.
  bool _popPending = false;

  @override
  void didUpdateWidget(covariant AngleShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    final calm = MediaQuery.disableAnimationsOf(context);
    if (oldWidget.full && !widget.full) {
      _popPending = false;
      _pop.value = 1;
      HapticFeedback.mediumImpact();
      if (calm) {
        _break.value = 1;
      } else {
        _break.forward(from: 0);
      }
    } else if (!oldWidget.full && widget.full) {
      _break.value = 1;
      _popPending = true;
    }
    if (_popPending && !widget.waiting) {
      _popPending = false;
      if (calm) {
        _pop.value = 1;
      } else {
        _pop.forward(from: 0);
      }
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
        final full = widget.full && !_popPending;
        final scale = full
            ? 0.6 + 0.4 * Curves.easeOutBack.transform(_pop.value)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: ShieldPainter(
              full: full,
              breaking: widget.full ? 1 : _break.value,
            ),
          ),
        );
      },
    );
  }
}

/// An angular, chamfered shield. [breaking] < 1 plays the break: a white
/// flash, two halves drifting apart and tilting as they fade, and gold
/// shards; at 1 only the lost shield's dim outline is left.
class ShieldPainter extends CustomPainter {
  const ShieldPainter({required this.full, this.breaking = 1});

  final bool full;
  final double breaking;

  /// The shield outline in a 20 × 20 box.
  static Path shape(Size size) {
    final k = size.width / 20;
    return Path()
      ..moveTo(4 * k, 1 * k)
      ..lineTo(16 * k, 1 * k)
      ..lineTo(19 * k, 4 * k)
      ..lineTo(19 * k, 11 * k)
      ..lineTo(10 * k, 19.5 * k)
      ..lineTo(1 * k, 11 * k)
      ..lineTo(1 * k, 4 * k)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 20;
    final path = shape(size);
    final centre = Offset(size.width / 2, size.height * 0.48);

    if (full) {
      _solid(canvas, size, path, LS.gold);
      return;
    }

    // The lost shield: a dim outline.
    final t = breaking.clamp(0.0, 1.0);
    canvas.drawPath(
      path,
      Paint()
        ..color = LS.gold.withValues(alpha: 0.25 * Curves.easeIn.transform(t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * k
        ..strokeJoin = StrokeJoin.miter,
    );
    if (t >= 1) {
      return;
    }

    // Flash white over the first 20%, then split and fade.
    final flash = t < 0.2 ? sin(pi * t / 0.2) : 0.0;
    final split = Curves.easeOut.transform(((t - 0.15) / 0.85).clamp(0, 1));
    final fade = 1 - split;
    final color = Color.lerp(LS.gold, Colors.white, flash)!;
    for (final side in const [-1, 1]) {
      canvas
        ..save()
        ..translate(centre.dx + side * 5 * k * split, centre.dy + 2 * k * split)
        ..rotate(side * 0.35 * split)
        ..translate(-centre.dx, -centre.dy)
        ..clipRect(
          side < 0
              ? Rect.fromLTWH(0, 0, size.width / 2, size.height)
              : Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
        );
      _solid(canvas, size, path, color.withValues(alpha: fade));
      canvas.restore();
    }

    // Shards from the crack.
    final shard = Paint()..color = LS.gold.withValues(alpha: fade);
    const angles = [-2.4, -0.7, 0.9, 2.2];
    for (var i = 0; i < angles.length; i++) {
      final a = angles[i];
      final reach = (6 + 3 * (i % 2)) * k * split;
      final at = centre + Offset(cos(a), sin(a)) * reach;
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(a + split * 2)
        ..drawPath(
          Path()
            ..moveTo(0, -1.6 * k)
            ..lineTo(1.4 * k, 1.2 * k)
            ..lineTo(-1.4 * k, 1.2 * k)
            ..close(),
          shard,
        )
        ..restore();
    }
  }

  void _solid(Canvas canvas, Size size, Path path, Color color) {
    final k = size.width / 20;
    canvas.drawPath(path, Paint()..color = color);
    // A subtle inner line, inset from the edge.
    final inner = shape(size).transform(
      (Matrix4.identity()
            ..translateByDouble(size.width * 0.2, size.height * 0.18, 0, 1)
            ..scaleByDouble(0.6, 0.6, 1, 1))
          .storage,
    );
    canvas.drawPath(
      inner,
      Paint()
        ..color = LS.bg.withValues(alpha: 0.3 * color.a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * k
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(ShieldPainter oldDelegate) =>
      oldDelegate.full != full || oldDelegate.breaking != breaking;
}
