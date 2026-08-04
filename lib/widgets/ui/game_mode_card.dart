import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/game_model.dart';
import 'game_brand_art.dart';
import 'primary_game_button.dart';

class GameModeCard extends StatelessWidget {
  const GameModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.game,
    this.bestScore,
    this.onPressed,
    this.compact = false,
    this.trailingLabel,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final GameType? game;
  final int? bestScore;
  final VoidCallback? onPressed;
  final bool compact;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? AppColors.textMuted;

    if (compact) {
      return Material(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GameArt(
                  game: game,
                  icon: icon,
                  accentColor: accentColor,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GameArt(
                  game: game,
                  icon: icon,
                  accentColor: accentColor,
                  size: 48,
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
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bestScore != null) ...[
              const SizedBox(height: 12),
              Text(
                'Best: $bestScore',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            PrimaryGameButton(
              label: trailingLabel ?? 'Play',
              icon: Icons.play_arrow_rounded,
              compact: true,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameArt extends StatelessWidget {
  const _GameArt({
    required this.game,
    required this.icon,
    required this.accentColor,
    required this.size,
  });

  final GameType? game;
  final IconData icon;
  final Color accentColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (game != null) {
      return GameBrandArt(game: game!, size: size, borderRadius: size * 0.3);
    }
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: accentColor, size: size * 0.46),
    );
  }
}
