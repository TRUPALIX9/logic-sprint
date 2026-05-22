import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/utils/player_name_validator.dart';
import '../../models/game_model.dart';
import '../../models/score_model.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/primary_button.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});

  final ScoreModel result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _submitted = false;
  bool _submitting = false;
  String? _submitMessage;

  Future<void> _submitScore() async {
    if (_submitted || _submitting || widget.result.finalScore <= 0) {
      return;
    }

    final service = context.read<LeaderboardService>();
    if (!service.canSubmitToday()) {
      setState(() {
        _submitMessage =
            'Daily leaderboard submission limit reached. Your local score is still saved.';
      });
      return;
    }

    var playerName = service.savedPlayerName;
    if (playerName == null) {
      playerName = await _promptForPlayerName();
      if (playerName == null) {
        return;
      }
    }

    setState(() {
      _submitting = true;
      _submitMessage = null;
    });

    final submitResult = await service.submitScore(
      playerName: playerName,
      score: widget.result.finalScore,
      gameType: widget.result.gameType,
      difficulty: widget.result.difficulty,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
      _submitMessage = submitResult.message;
      if (submitResult.success) {
        _submitted = true;
      }
    });
  }

  Future<String?> _promptForPlayerName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Display name'),
          content: TextField(
            controller: controller,
            maxLength: 20,
            decoration: const InputDecoration(
              hintText: 'Letters, numbers, spaces, _ -',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final error = PlayerNameValidator.validate(controller.text);
                if (error != null) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
                Navigator.of(
                  dialogContext,
                ).pop(PlayerNameValidator.normalize(controller.text));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.result.finalScore > 0 && !_submitted;
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
                    widget.result.gameType.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(widget.result.difficulty.title),
                  const SizedBox(height: 18),
                  Text(
                    '${widget.result.finalScore}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.result.isNewBest
                        ? 'New best score!'
                        : 'Best score: ${widget.result.bestScore}',
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
          if (widget.result.finalScore > 0) ...[
            const SizedBox(height: 24),
            PrimaryButton(
              label: _submitted ? 'Score Submitted' : 'Submit Score',
              icon: _submitted
                  ? Icons.check_circle_rounded
                  : Icons.cloud_upload_rounded,
              onPressed: canSubmit && !_submitting ? _submitScore : null,
            ),
            if (_submitting) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_submitMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _submitMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Play Again',
            icon: Icons.replay_rounded,
            onPressed: () => Navigator.of(context).pushReplacementNamed(
              AppRoutes.gameRoute(widget.result.gameType),
              arguments: widget.result.difficulty,
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
