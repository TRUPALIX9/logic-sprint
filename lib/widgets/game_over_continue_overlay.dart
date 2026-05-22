import 'package:flutter/material.dart';

import '../models/second_life_config.dart';
import 'watch_ad_second_life_button.dart';

class GameOverContinueOverlay extends StatelessWidget {
  const GameOverContinueOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.config,
    required this.secondLifeAvailable,
    required this.adReady,
    required this.isShowingAd,
    this.onWatchAd,
    required this.onEndGame,
    required this.onPlayAgain,
    required this.onBackToGames,
  });

  final int score;
  final int bestScore;
  final SecondLifeConfig config;
  final bool secondLifeAvailable;
  final bool adReady;
  final bool isShowingAd;
  final VoidCallback? onWatchAd;
  final VoidCallback onEndGame;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToGames;

  @override
  Widget build(BuildContext context) {
    final title = secondLifeAvailable
        ? config.failTitle
        : SecondLifeConfig.gameOverTitle;
    final message = secondLifeAvailable ? config.failMessage : null;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Score: $score',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  Text('Best: $bestScore', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (secondLifeAvailable) ...[
                    WatchAdSecondLifeButton(
                      adReady: adReady && !isShowingAd,
                      isLoading: isShowingAd,
                      onPressed: onWatchAd,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isShowingAd ? null : onEndGame,
                      child: const Text(SecondLifeConfig.endGameLabel),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: onPlayAgain,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(SecondLifeConfig.playAgainLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onBackToGames,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text(SecondLifeConfig.backToGamesLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
