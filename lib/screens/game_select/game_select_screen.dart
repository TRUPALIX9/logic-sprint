import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/brand/game_brand.dart';
import '../../core/constants/app_routes.dart';
import '../../models/game_model.dart';
import '../../services/app_state.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/game_card.dart';

class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Mini Games',
        subtitle: 'Choose a fast challenge',
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: availableGames.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final game = availableGames[index];
          final brand = GameBrand.forGame(game.type);
          return GameCard(
            title: game.title,
            description: game.description,
            icon: game.icon,
            accentColor: brand.accent,
            bestScore: appState.overallBestFor(game.type),
            enabled: !game.isComingSoon,
            onPressed: game.isComingSoon
                ? null
                : () => Navigator.of(context).pushNamed(
                      AppRoutes.difficulty,
                      arguments: game.type,
                    ),
          )
              .animate()
              .fadeIn(delay: Duration(milliseconds: 80 * index))
              .slideY(begin: 0.08);
        },
      ),
    );
  }
}
