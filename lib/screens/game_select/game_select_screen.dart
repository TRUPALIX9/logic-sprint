import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../models/game_model.dart';
import '../../services/app_state.dart';
import '../../widgets/ui/app_scaffold.dart';
import '../../widgets/ui/game_mode_card.dart';
import '../../widgets/ui/section_title.dart';

class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return AppScaffold(
      title: 'Mini Games',
      subtitle: 'Choose a challenge',
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: availableGames.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const SectionTitle(
              title: 'Mini Games',
              subtitle: 'Each game trains a different brain skill',
            );
          }

          final game = availableGames[index - 1];
          return GameModeCard(
            title: game.title,
            description: game.description,
            icon: game.icon,
            game: game.type,
            accentColor: game.accentColor,
            bestScore: appState.overallBestFor(game.type),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.difficulty,
              arguments: game.type,
            ),
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: 60 * index))
              .slideY(begin: 0.06);
        },
      ),
    );
  }
}
