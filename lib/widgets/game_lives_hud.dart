import 'package:flutter/material.dart';

import 'app_gradient_background.dart';

/// Top HUD: back, title, score, hearts, optional level.
class GameLivesHud extends StatelessWidget {
  const GameLivesHud({
    super.key,
    required this.title,
    required this.score,
    required this.lives,
    required this.maxLives,
    this.level,
    this.onBack,
  });

  final String title;
  final int score;
  final int lives;
  final int maxLives;
  final int? level;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppGradientBackground.textPrimary,
            ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppGradientBackground.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Score: $score',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppGradientBackground.cyanAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            ...List.generate(maxLives, (index) {
              final filled = index < lives;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  filled
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: filled
                      ? AppGradientBackground.lifeLost
                      : AppGradientBackground.textSecondary.withValues(
                          alpha: 0.45,
                        ),
                  size: 26,
                ),
              );
            }),
            const Spacer(),
            if (level != null)
              Text(
                'Level $level',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppGradientBackground.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
