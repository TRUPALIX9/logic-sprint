import 'package:flutter/material.dart';

import '../../core/brand/game_brand.dart';
import '../../core/constants/app_routes.dart';
import '../../models/game_model.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/primary_button.dart';

class DifficultyScreen extends StatelessWidget {
  const DifficultyScreen({super.key, required this.gameType});

  final GameType gameType;

  @override
  Widget build(BuildContext context) {
    final brand = GameBrand.forGame(gameType);
    return Scaffold(
      appBar: CustomAppBar(
        title: gameType.title,
        subtitle: 'Choose your difficulty',
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: DifficultyLevel.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final difficulty = DifficultyLevel.values[index];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index == 0) ...[
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: brand.gradient,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    difficulty.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(difficulty.shortHint),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Start ${difficulty.title}',
                    icon: Icons.bolt_rounded,
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.gameRoute(gameType),
                      arguments: difficulty,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
