import 'package:flutter/material.dart';

class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    super.key,
    required this.score,
    required this.streak,
    required this.correctAnswers,
  });

  final int score;
  final int streak;
  final int correctAnswers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ScoreStat(label: 'Score', value: '$score'),
        const SizedBox(width: 12),
        _ScoreStat(label: 'Streak', value: '$streak'),
        const SizedBox(width: 12),
        _ScoreStat(label: 'Correct', value: '$correctAnswers'),
      ],
    );
  }
}

class _ScoreStat extends StatelessWidget {
  const _ScoreStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}
