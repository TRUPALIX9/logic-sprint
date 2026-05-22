import 'package:flutter/material.dart';

/// Global space gradient — no pure white backgrounds.
class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  static const Color backgroundTop = Color(0xFF130B3F);
  static const Color backgroundMiddle = Color(0xFF163B78);
  static const Color backgroundBottom = Color(0xFF74B7D2);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD7E7F5);
  static const Color cyanAccent = Color(0xFF21D4FD);
  static const Color orangeAccent = Color(0xFFFF9F1C);
  static const Color lifeLost = Color(0xFFFF4D6D);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundMiddle, backgroundBottom],
    stops: [0.0, 0.45, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: backgroundGradient),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: _Blob(size: 180, color: cyanAccent.withValues(alpha: 0.1)),
          ),
          Positioned(
            top: 140,
            left: -40,
            child: _Blob(
              size: 130,
              color: orangeAccent.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 20,
            child: _Blob(
              size: 100,
              color: textSecondary.withValues(alpha: 0.06),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class ThemedGamePanel extends StatelessWidget {
  const ThemedGamePanel({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final border = accent ?? AppGradientBackground.cyanAccent;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0D1B3D).withValues(alpha: 0.72),
        border: Border.all(color: border.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
