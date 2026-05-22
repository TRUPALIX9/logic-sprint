import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/game_model.dart';
import '../../services/app_state.dart';
import '../../widgets/admob_banner.dart';
import '../../widgets/app_gradient_background.dart';
import '../../widgets/ui/home_game_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _bannerReserve = 72;

  void _openGame(BuildContext context, GameModel game) {
    Navigator.of(context).pushNamed(AppRoutes.gameRoute(game.type));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeHeader(
                      onSettings: () =>
                          Navigator.of(context).pushNamed(AppRoutes.settings),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Mini Games',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          bottom:
                              _bannerReserve +
                              MediaQuery.paddingOf(context).bottom +
                              20,
                        ),
                        itemCount: homeLauncherGames.length,
                        itemBuilder: (context, index) {
                          final game = homeLauncherGames[index];
                          return HomeGameCard(
                            game: game,
                            bestScore: appState.overallBestFor(game.type),
                            highestLevel: appState.highestLevelFor(game.type),
                            onTap: () => _openGame(context, game),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(top: false, child: const AdMobBanner()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/images/logicsprint_logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                AppStrings.appSubtitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}
