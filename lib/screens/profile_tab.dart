import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../services/leaderboard.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';

/// Display name and personal bests.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = context.read<Leaderboard>().savedName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        const DisplayText('Profile', size: 30),
        const SizedBox(height: 16),
        ChamferBox(
          cut: Cut.lg,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const ChamferBox(
                cut: Cut.sm,
                width: 48,
                height: 48,
                borderColor: null,
                color: LS.surface2,
                child: Icon(Icons.person_outline_rounded, color: LS.teal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MonoLabel('Display name', size: 10, color: LS.dim),
                    const SizedBox(height: 4),
                    name == null
                        ? Text(
                            'Set when you post your first score',
                            style: LSText.body(14, color: LS.muted),
                          )
                        : DisplayText(name, size: 22, maxLines: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const MonoLabel('Your bests'),
        const SizedBox(height: 10),
        for (final game in GameId.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BestCard(game: game, app: app),
          ),
      ],
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard({required this.game, required this.app});

  final GameId game;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final difficulties = game.hasDifficulty
        ? Difficulty.values
        : const [GameId.rampDifficulty];
    final bests = [for (final d in difficulties) app.best(game, d)];
    final top = bests.reduce((a, b) => a > b ? a : b);
    return ChamferBox(
      cut: Cut.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameTile(game: game, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DisplayText(game.title, size: 20, maxLines: 1),
                    const SizedBox(height: 3),
                    MonoLabel(game.skill, size: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, difficulty) in difficulties.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    color: LS.surface2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonoLabel(
                          game.hasDifficulty ? difficulty.label : 'Best',
                          size: 10,
                          color: LS.dim,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bests[i] > 0 ? '${bests[i]}' : '—',
                          style: LSText.mono(
                            19,
                            weight: FontWeight.w700,
                            spacing: 0,
                            color: bests[i] == 0
                                ? LS.dim
                                : bests[i] == top
                                ? game.accent
                                : LS.text,
                          ),
                        ),
                        if (app.bestTime(game, difficulty) case final time?)
                          if (bests[i] > 0) ...[
                            const SizedBox(height: 2),
                            MonoLabel(
                              formatDuration(time),
                              size: 10,
                              color: LS.dim,
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
