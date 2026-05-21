import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'primary_button.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.bestScore,
    required this.enabled,
    this.accentColor,
    this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final int bestScore;
  final bool enabled;
  final Color? accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.72);
    final accent = accentColor ?? AppColors.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: enabled
                    ? accent.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: enabled ? accent : Colors.grey,
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 14),
            Text(
              enabled ? 'Best score: $bestScore' : 'Coming soon',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: enabled ? 'Play' : 'Coming Soon',
              onPressed: enabled ? onPressed : null,
              icon: enabled ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
