import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';
import '../../models/game_model.dart';
import '../../models/score_model.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/primary_button.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final ScoreModel result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Round Complete',
        subtitle: 'Your latest sprint',
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    result.gameType.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(result.difficulty.title),
                  const SizedBox(height: 18),
                  Text(
                    '${result.finalScore}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.isNewBest ? 'New best score!' : 'Best score: ${result.bestScore}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _ResultStat(label: 'Correct', value: '${result.correctAnswers}'),
              _ResultStat(label: 'Wrong', value: '${result.wrongAnswers}'),
              _ResultStat(
                label: 'Accuracy',
                value: '${result.accuracyPercentage.toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Play Again',
            icon: Icons.replay_rounded,
            onPressed: () => Navigator.of(context).pushReplacementNamed(
              AppRoutes.gameRoute(result.gameType),
              arguments: result.difficulty,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Back to Home',
            icon: Icons.home_rounded,
            isSecondary: true,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 28,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
