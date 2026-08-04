import 'package:flutter/material.dart';

import '../core/brand/game_brand.dart';
import '../models/game_model.dart';

/// In-game score, timer, and progress stats with optional per-game brand accent.
class GameStatusHeader extends StatelessWidget {
  const GameStatusHeader({
    super.key,
    required this.score,
    this.game,
    this.lives,
    this.round,
    this.remainingSeconds,
    this.streak,
    this.correctAnswers,
    this.matches,
  });

  final int score;
  final GameType? game;
  final int? lives;
  final int? round;
  final int? remainingSeconds;
  final int? streak;
  final int? correctAnswers;
  final String? matches;

  @override
  Widget build(BuildContext context) {
    final brand = game == null ? null : GameBrand.forGame(game!);
    final stats = <_Stat>[
      _Stat(label: 'Score', value: '$score'),
      if (streak != null) _Stat(label: 'Streak', value: '$streak'),
      if (correctAnswers != null)
        _Stat(label: 'Correct', value: '$correctAnswers'),
      if (lives != null) _Stat(label: 'Lives', value: '$lives'),
      if (round != null) _Stat(label: 'Round', value: '$round'),
      if (remainingSeconds != null)
        _Stat(label: 'Time', value: '${remainingSeconds}s'),
      if (matches != null) _Stat(label: 'Pairs', value: matches!),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: brand?.gradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _StatTile(stat: stats[i], accent: brand?.accent)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, this.accent});

  final _Stat stat;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: accent == null
            ? null
            : Border.all(color: accent!.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            stat.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(stat.label),
        ],
      ),
    );
  }
}
