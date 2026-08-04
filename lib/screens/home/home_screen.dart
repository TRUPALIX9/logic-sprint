import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/game_model.dart';
import '../../services/app_state.dart';
import '../../widgets/ui/brand_gradient_header.dart';
import '../../widgets/ui/game_mode_card.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/ui/primary_game_button.dart';
import '../../widgets/ui/section_title.dart';
import '../../widgets/ui/stat_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final featured = availableGames.first;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandGradientHeader()
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.08),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const StatChip(
                    icon: Icons.timer_rounded,
                    label: '30 Sec Rounds',
                  ),
                  StatChip(
                    icon: Icons.extension_rounded,
                    label: '${availableGames.length} Mini Games',
                  ),
                  const StatChip(
                    icon: Icons.emoji_events_rounded,
                    label: 'Top 100 Online',
                  ),
                ],
              ).animate().fadeIn(delay: 80.ms),
              const SizedBox(height: 16),
              PrimaryGameButton(
                label: 'Start Playing',
                icon: Icons.play_arrow_rounded,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.gameSelect),
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),
              const SectionTitle(
                title: "Today's Challenge",
                subtitle: 'Beat your best score',
              ),
              const SizedBox(height: 12),
              GameModeCard(
                title: featured.title,
                description: featured.description,
                icon: featured.icon,
                game: featured.type,
                accentColor: featured.accentColor,
                bestScore: appState.overallBestFor(featured.type),
                trailingLabel: 'Play Now',
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.difficulty,
                  arguments: featured.type,
                ),
              ).animate().fadeIn(delay: 180.ms),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Mini Games'),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  for (final game in availableGames)
                    GameModeCard(
                      compact: true,
                      title: game.title,
                      description: game.description,
                      icon: game.icon,
                      game: game.type,
                      accentColor: game.accentColor,
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.difficulty,
                        arguments: game.type,
                      ),
                    ),
                  GameModeCard(
                    compact: true,
                    title: 'Leaderboard',
                    description: 'Global top scores',
                    icon: Icons.leaderboard_rounded,
                    accentColor: Theme.of(context).colorScheme.secondary,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.leaderboard),
                  ),
                ],
              ).animate().fadeIn(delay: 240.ms),
              const SizedBox(height: 20),
              _NavRow(
                items: [
                  _NavItem(
                    icon: Icons.videogame_asset_rounded,
                    label: 'Games',
                    route: AppRoutes.gameSelect,
                  ),
                  _NavItem(
                    icon: Icons.emoji_events_rounded,
                    label: 'Scores',
                    route: AppRoutes.highScores,
                  ),
                  _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    route: AppRoutes.settings,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const AdBannerWidget(),
              const SizedBox(height: 16),
              Text(
                AppStrings.appTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.items});

  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _NavButton(item: items[i]),
          ),
        ],
      ],
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item});

  final _NavItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(item.route),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(item.icon, size: 22),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
