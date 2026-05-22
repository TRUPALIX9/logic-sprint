import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/life_game_constants.dart';
import '../../../models/game_model.dart';
import '../../../models/second_life_config.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/answer_button.dart';
import '../../../widgets/app_gradient_background.dart';
import '../../../widgets/game_second_life_layer.dart';
import '../../../widgets/game_screen_shell.dart';
import 'quick_math_controller.dart';

class QuickMathScreen extends StatefulWidget {
  const QuickMathScreen({super.key});

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
    )..addListener(_handleControllerUpdate);
    unawaited(_controller.initialize());
  }

  Future<void> _handleControllerUpdate() async {
    if (_didNavigate ||
        !_controller.isRoundComplete ||
        _controller.result == null) {
      return;
    }

    _didNavigate = true;
    await context.read<AppState>().recordHighScore(
      GameType.quickMath,
      LifeGameConstants.storageDifficulty,
      _controller.score,
      highestLevel: _controller.level,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.result, arguments: _controller.result);
  }

  Future<void> _onPlayAgain() async {
    _didNavigate = false;
    _controller.resetGame();
    await _controller.initialize();
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
    final config = SecondLifeConfig.forGame(GameType.quickMath);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GameSecondLifeLayer(
          config: config,
          session: _controller.secondLife,
          score: _controller.score,
          bestScore: _controller.bestScore,
          onEndGameFinal: _controller.endGameFinal,
          onPlayAgain: _onPlayAgain,
          onResumeFromSecondLife: _controller.resumeFromSecondLifeReward,
          child: GameScreenShell(
            title: 'Quick Math',
            score: _controller.score,
            lives: _controller.lives,
            level: _controller.level,
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ThemedGamePanel(
                          child: Column(
                            children: [
                              Text(
                                _controller.currentQuestion?.prompt ?? '',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      color: AppGradientBackground.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 1.5,
                                ),
                            itemCount:
                                _controller.currentQuestion?.options.length ??
                                0,
                            itemBuilder: (context, index) {
                              final answer =
                                  _controller.currentQuestion!.options[index];
                              return AnswerButton(
                                label: answer,
                                onPressed:
                                    _controller.isAnswerLocked ||
                                        _controller.isGameplayPaused
                                    ? null
                                    : () => unawaited(
                                        _controller.submitAnswer(answer),
                                      ),
                                showFeedback: _controller.isAnswerLocked,
                                isCorrectChoice:
                                    answer ==
                                    _controller.currentQuestion!.correctAnswer,
                                isSelected:
                                    answer == _controller.selectedAnswer,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
