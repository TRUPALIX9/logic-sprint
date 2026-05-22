import 'package:flutter/material.dart';

import '../../../core/brand/brand_palette.dart';

class PatternDotTile extends StatelessWidget {
  const PatternDotTile({
    super.key,
    required this.index,
    required this.isActive,
    required this.onTap,
  });

  final int index;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? BrandPalette.electricBlue
              : BrandPalette.softBackground.withValues(alpha: 0.25),
          border: Border.all(color: BrandPalette.electricBlue, width: 2),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: BrandPalette.electricBlue.withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
