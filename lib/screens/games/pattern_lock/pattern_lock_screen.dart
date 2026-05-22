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
import '../../../widgets/app_gradient_background.dart';
import '../../../widgets/game_second_life_layer.dart';
import '../../../widgets/game_screen_shell.dart';
import '../../../widgets/primary_button.dart';
import 'pattern_lock_controller.dart';
import 'pattern_lock_widgets.dart';

class PatternLockScreen extends StatefulWidget {
  const PatternLockScreen({super.key});

  @override
  State<PatternLockScreen> createState() => _PatternLockScreenState();
}

class _PatternLockScreenState extends State<PatternLockScreen> {
  late final PatternLockController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = PatternLockController(
      storage: context.read<LocalStorageService>(),
      soundService: context.read<SoundService>(),
    )..addListener(_handleControllerUpdate);
    unawaited(_controller.initialize());
  }

  Future<void> _onPlayAgain() async {
    _didNavigate = false;
    _controller.resetGame();
    await _controller.initialize();
  }

  Future<void> _handleControllerUpdate() async {
    if (_didNavigate ||
        !_controller.isRoundComplete ||
        _controller.result == null) {
      return;
    }

    _didNavigate = true;
    await context.read<AppState>().recordHighScore(
      _controller.gameType,
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

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = SecondLifeConfig.forGame(GameType.patternLock);

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
            title: 'Pattern Lock',
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
                          accent: const Color(0xFF818CF8),
                          child: Column(
                            children: [
                              Text(
                                _controller.statusMessage,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppGradientBackground.textPrimary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _controller.dotCount,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 24,
                                    mainAxisSpacing: 24,
                                  ),
                              itemBuilder: (context, index) {
                                return PatternDotTile(
                                  index: index,
                                  isActive: _controller.isDotActive(index),
                                  onTap:
                                      _controller.isAcceptingInput &&
                                          !_controller.isGameplayPaused
                                      ? () => _controller.addDot(index)
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                label: 'Clear',
                                isSecondary: true,
                                onPressed: _controller.isAcceptingInput
                                    ? _controller.clearPlayerPattern
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Submit',
                                onPressed:
                                    _controller.isAcceptingInput &&
                                        _controller.playerPattern.length ==
                                            _controller.targetPattern.length
                                    ? () =>
                                          unawaited(_controller.submitPattern())
                                    : null,
                              ),
                            ),
                          ],
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
