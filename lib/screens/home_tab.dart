import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../games/games.dart';
import '../models/game.dart';
import '../state/app_state.dart';
import '../ui/ad_banner.dart';
import '../ui/brand.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'game_sheet.dart';
import 'settings_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final last = app.lastPlayed;
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 8),
            child: Row(
              children: [
                const LogoMark(size: 30),
                const SizedBox(width: 10),
                const Wordmark(size: 20),
                const Spacer(),
                LSIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  color: LS.muted,
                  onPressed: () =>
                      Navigator.of(context).push(SettingsScreen.route()),
                ),
              ],
            ),
          ),
        ),
        // The 2×2 game grid stretches to fill the screen; on short screens it
        // keeps its natural height and the page scrolls.
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                // No bottom padding here: SliverFillRemaining would ignore it
                // and push the last row under the nav bar (spacer below instead).
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DisplayText('Ready to sprint?', size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Pick a game. Beat your best.',
                        style: LSText.body(15, color: LS.muted),
                      ),
                      const SizedBox(height: 20),
                      if (last != null) ...[
                        _JumpBackIn(
                          game: last.$1,
                          difficulty: last.$2,
                          best: app.best(last.$1, last.$2),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        children: [
                          const MonoLabel('Games', size: 12),
                          const Spacer(),
                          MonoLabel(
                            GameId.values.length.toString().padLeft(2, '0'),
                            size: 12,
                            color: LS.dim,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final (i, pair) in [
                        GameId.values.sublist(0, 2),
                        GameId.values.sublist(2),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 178),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final (j, game) in pair.indexed) ...[
                                  if (j > 0) const SizedBox(width: 12),
                                  Expanded(
                                    child: _GameCard(
                                      game: game,
                                      best: Difficulty.values
                                          .map((d) => app.best(game, d))
                                          .reduce(math.max),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const AdBanner(),
      ],
    );
  }
}

class _JumpBackIn extends StatelessWidget {
  const _JumpBackIn({
    required this.game,
    required this.difficulty,
    required this.best,
  });

  final GameId game;
  final Difficulty difficulty;
  final int best;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.lg,
      borderColor: LS.teal.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(gameRoute(game, difficulty)),
      child: Row(
        children: [
          GameTile(game: game, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Jump back in', color: LS.teal),
                const SizedBox(height: 4),
                DisplayText(game.title, size: 22, maxLines: 1),
                const SizedBox(height: 4),
                MonoLabel(
                  game.hasDifficulty
                      ? '${difficulty.label} · best $best'
                      : 'Best $best',
                ),
              ],
            ),
          ),
          const ChamferBox(
            cut: Cut.sm,
            width: 52,
            height: 52,
            borderColor: null,
            color: LS.teal,
            child: Icon(Icons.play_arrow_rounded, color: LS.bg, size: 26),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.best});

  final GameId game;
  final int best;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.lg,
      padding: const EdgeInsets.all(14),
      onTap: () => showGameSheet(context, game),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameTile(game: game, size: 44),
          const Spacer(),
          DisplayText(game.title, size: 20, maxLines: 2),
          const SizedBox(height: 4),
          MonoLabel(game.skill),
          const SizedBox(height: 10),
          const Divider(height: 1, color: LS.line),
          const SizedBox(height: 10),
          MonoLabel(
            best > 0 ? 'Best $best' : 'Not played',
            size: 12,
            weight: FontWeight.w700,
            color: best > 0 ? game.accent : LS.dim,
          ),
        ],
      ),
    );
  }
}
