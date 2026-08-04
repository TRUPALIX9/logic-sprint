import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../models/game_model.dart';
import '../../../services/ad_service.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/answer_button.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/game_status_header.dart';
import '../../../widgets/timer_bar.dart';
import 'quick_math_controller.dart';

class QuickMathScreen extends StatefulWidget {
  const QuickMathScreen({super.key, required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  State<QuickMathScreen> createState() => _QuickMathScreenState();
}

class _QuickMathScreenState extends State<QuickMathScreen> {
  late final QuickMathController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = QuickMathController(
      storage: context.read<LocalStorageService>(),
      soundService: context.read<SoundService>(),
      difficulty: widget.difficulty,
    )..addListener(_handleControllerUpdate);
    unawaited(_controller.initialize());
  }

  Future<void> _handleControllerUpdate() async {
    if (_didNavigate || !_controller.isRoundComplete || _controller.result == null) {
      return;
    }

    _didNavigate = true;
    await context.read<AppState>().recordHighScore(
          _controller.gameType,
          widget.difficulty,
          _controller.score,
        );
    if (!mounted) {
      return;
    }

    context.read<AdService>().showInterstitialAd(
      context: context,
      onAdClosed: () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.result,
            arguments: _controller.result,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'Quick Math',
            subtitle: widget.difficulty.title,
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TimerBar(
                        progress: _controller.progress,
                        secondsRemaining: _controller.secondsRemaining,
                      ),
                      const SizedBox(height: 18),
                      GameStatusHeader(
                        game: GameType.quickMath,
                        score: _controller.score,
                        streak: _controller.currentStreak,
                        correctAnswers: _controller.correctAnswers,
                        remainingSeconds: _controller.secondsRemaining,
                      ),
                      const SizedBox(height: 18),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                'Solve as many as you can',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                _controller.currentQuestion?.prompt ?? '',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _controller.currentQuestion?.options.length ?? 0,
                        itemBuilder: (context, index) {
                          final answer = _controller.currentQuestion!.options[index];
                          return AnswerButton(
                            label: answer,
                            onPressed: _controller.isAnswerLocked
                                ? null
                                : () => unawaited(_controller.submitAnswer(answer)),
                            showFeedback: _controller.isAnswerLocked,
                            isCorrectChoice:
                                answer == _controller.currentQuestion!.correctAnswer,
                            isSelected: answer == _controller.selectedAnswer,
                          );
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
