import 'package:flutter/material.dart';

import 'ui/game_tactile_button.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isSecondary = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );

    final height = compact ? 44.0 : 50.0;

    if (isSecondary) {
      final Color faceColor = isDark ? const Color(0xFF221752) : Colors.white;
      final Color depthColor = isDark ? const Color(0xFF100A30) : const Color(0xFFCBD5E1);
      final Color textColor = isDark ? Colors.white : const Color(0xFF120A3D);

      return GameTactileButton(
        color: faceColor,
        bottomColor: depthColor,
        height: height,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    // Primary uses beautiful Sprint Orange / Game CTA theme colors!
    return GameTactileButton(
      color: const Color(0xFFFF8A00),
      bottomColor: const Color(0xFFCC5F00),
      height: height,
      onPressed: onPressed,
      child: child,
    );
  }
}
