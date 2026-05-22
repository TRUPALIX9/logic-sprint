import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'ui/primary_game_button.dart';

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
    final mutedColor = theme.textTheme.bodySmall?.color ?? AppColors.textMuted;
    final accent = accentColor ?? AppColors.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: enabled
                        ? accent.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: enabled ? accent : Colors.grey),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              enabled ? 'Best: $bestScore' : 'Coming soon',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryGameButton(
              label: enabled ? 'Play' : 'Coming Soon',
              compact: true,
              onPressed: enabled ? onPressed : null,
              icon: enabled
                  ? Icons.play_arrow_rounded
                  : Icons.lock_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
