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
import 'emoji_match_controller.dart';
import 'emoji_match_widgets.dart';

class EmojiMatchScreen extends StatefulWidget {
  const EmojiMatchScreen({super.key});

  @override
  State<EmojiMatchScreen> createState() => _EmojiMatchScreenState();
}

class _EmojiMatchScreenState extends State<EmojiMatchScreen> {
  late final EmojiMatchController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = EmojiMatchController(
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
    final config = SecondLifeConfig.forGame(GameType.emojiMatch);

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
            title: 'Emoji Match',
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
                          accent: const Color(0xFF2DD4BF),
                          child: Text(
                            _controller.statusMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppGradientBackground.textPrimary,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      _controller.config.crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: _controller.cards.length,
                            itemBuilder: (context, index) {
                              return EmojiCardTile(
                                card: _controller.cards[index],
                                onTap:
                                    _controller.isCheckingPair ||
                                        _controller.isGameplayPaused
                                    ? null
                                    : () => unawaited(
                                        _controller.handleCardTap(index),
                                      ),
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
