import 'package:flutter/material.dart';

/// Eases [child] in (fade plus a slight grow) whenever [revealKey] changes,
/// so a new word or problem arrives instead of popping in. While [hidden]
/// (the get-ready countdown after a revive) it fades out and stays out, then
/// fades back in. Reduce motion: no grow, instant swaps.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.revealKey,
    required this.child,
    this.hidden = false,
  });

  static const duration = Duration(milliseconds: 180);

  final Object revealKey;
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: hidden ? 0 : 1,
      duration: calm ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: TweenAnimationBuilder<double>(
        key: ObjectKey(revealKey),
        tween: Tween(begin: calm ? 1 : 0, end: 1),
        duration: calm ? Duration.zero : duration,
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
        child: child,
      ),
    );
  }
}
