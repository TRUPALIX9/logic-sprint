import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../models/game_model.dart';
import '../../models/score_model.dart';
import '../../services/final_score_service.dart';
import '../../widgets/app_gradient_background.dart';
import '../../widgets/primary_button.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});

  final ScoreModel result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _handled = false;
  String? _leaderboardMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFinalScore());
  }

  Future<void> _onFinalScore() async {
    if (_handled) {
      return;
    }
    _handled = true;

    final outcome = await context.read<FinalScoreService>().handleFinalScore(
      widget.result,
    );
    if (!mounted) {
      return;
    }
    setState(() => _leaderboardMessage = outcome.message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppGradientBackground.textPrimary,
                  ),
                  Expanded(
                    child: Text(
                      'Round Complete',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppGradientBackground.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ThemedGamePanel(
                child: Column(
                  children: [
                    Text(
                      widget.result.gameType.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppGradientBackground.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.result.finalScore}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppGradientBackground.cyanAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.result.isNewBest
                          ? 'New personal best!'
                          : 'Best: ${widget.result.bestScore}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppGradientBackground.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Level ${widget.result.level}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppGradientBackground.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _ResultStat(
                    label: 'Correct',
                    value: '${widget.result.correctAnswers}',
                  ),
                  _ResultStat(
                    label: 'Wrong',
                    value: '${widget.result.wrongAnswers}',
                  ),
                  _ResultStat(
                    label: 'Accuracy',
                    value:
                        '${widget.result.accuracyPercentage.toStringAsFixed(0)}%',
                  ),
                ],
              ),
              if (_leaderboardMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _leaderboardMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppGradientBackground.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Play Again',
                icon: Icons.replay_rounded,
                onPressed: () => Navigator.of(context).pushReplacementNamed(
                  AppRoutes.gameRoute(widget.result.gameType),
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Back to Home',
                icon: Icons.home_rounded,
                isSecondary: true,
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
              ),
            ],
          ),
        ),
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
      child: ThemedGamePanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppGradientBackground.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppGradientBackground.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
