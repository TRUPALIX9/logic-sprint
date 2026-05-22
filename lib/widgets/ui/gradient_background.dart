import 'package:flutter/material.dart';

import '../../core/brand/brand_palette.dart';

/// Full-screen space gradient with subtle decorative blobs.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF120A3D),
            Color(0xFF1A3A6E),
            Color(0xFF2A6F9E),
            Color(0xFFB8D9E8),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: _Blob(
              size: 160,
              color: BrandPalette.brainCyan.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            top: 120,
            left: -30,
            child: _Blob(
              size: 120,
              color: BrandPalette.electricBlue.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            bottom: 180,
            right: 24,
            child: _Blob(size: 90, color: Colors.white.withValues(alpha: 0.06)),
          ),
          ..._stars(),
          child,
        ],
      ),
    );
  }

  List<Widget> _stars() {
    const positions = <Offset>[
      Offset(24, 80),
      Offset(80, 140),
      Offset(200, 60),
      Offset(300, 200),
      Offset(40, 320),
      Offset(280, 400),
    ];
    return [
      for (final offset in positions)
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Icon(
            Icons.circle,
            size: 3,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
    ];
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
