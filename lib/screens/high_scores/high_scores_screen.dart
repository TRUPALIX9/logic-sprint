import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_model.dart';
import '../../services/app_state.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/empty_state.dart';

class HighScoresScreen extends StatelessWidget {
  const HighScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final hasScores = GameType.values
        .where((game) => game.isPlayable)
        .any((game) => appState.overallBestFor(game) > 0);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'High Scores',
        subtitle: 'Best scores by game and difficulty',
      ),
      body: hasScores
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: GameType.values
                  .where((game) => game.isPlayable)
                  .map(
                    (game) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              ...DifficultyLevel.values.map(
                                (difficulty) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(difficulty.title)),
                                      Text(
                                        '${appState.bestScoreFor(game, difficulty)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          : const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No scores yet',
              message:
                  'Play a few rounds and your best scores will show up here for each difficulty.',
            ),
    );
  }
}
