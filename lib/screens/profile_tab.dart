import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../models/run_record.dart';
import '../services/leaderboard.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'name_sheet.dart';

/// Display name, personal bests with play counts, and the local run History.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  /// History rows shown (Storage keeps the last 100).
  static const _historyShown = 30;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final leaderboard = context.watch<Leaderboard>();
    final history = leaderboard.history;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        const DisplayText('Profile', size: 30),
        const SizedBox(height: 16),
        _NameCard(name: leaderboard.savedName, runs: app.totalPlays),
        const SizedBox(height: 22),
        const MonoLabel('Your bests'),
        const SizedBox(height: 10),
        // Timed games first: their cards carry the most detail.
        for (final game in [
          ...GameId.values.where((g) => g.tracksTime),
          ...GameId.values.where((g) => !g.tracksTime),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BestCard(game: game, app: app),
          ),
        const SizedBox(height: 12),
        const Row(
          children: [
            MonoLabel('History'),
            Spacer(),
            MonoLabel('On this device only', size: 10, color: LS.dim),
          ],
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          Text(
            'Finished runs show up here.',
            style: LSText.body(15, color: LS.muted),
          )
        else
          for (final run in history.take(_historyShown))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _HistoryRow(run: run),
            ),
      ],
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({required this.name, required this.runs});

  final String? name;
  final int runs;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    return ChamferBox(
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
                if (name == null)
                  Text('Not set yet', style: LSText.body(15, color: LS.muted))
                else
                  DisplayText(name, size: 22, maxLines: 1),
                const SizedBox(height: 4),
                MonoLabel(
                  runs == 1 ? '1 run played' : '$runs runs played',
                  size: 10,
                  color: LS.dim,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CardAction(
            label: name == null ? 'Set name' : 'Edit',
            onTap: () => showNameSheet(context),
          ),
        ],
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard({required this.game, required this.app});

  final GameId game;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final bests = {for (final d in Difficulty.values) d: app.best(game, d)};
    final top = bests.values.reduce((a, b) => a > b ? a : b);
    const ramp = GameId.rampDifficulty;
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: game.hasDifficulty
                  ? [
                      for (final (i, difficulty)
                          in Difficulty.values.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _Cell(
                            label: difficulty.label,
                            value: bests[difficulty]!,
                            color: bests[difficulty] == top
                                ? game.accent
                                : LS.text,
                            notes: [
                              if (game.tracksTime && bests[difficulty]! > 0)
                                if (app.bestTime(game, difficulty)
                                    case final time?)
                                  formatDuration(time),
                              'Played ${app.plays(game, difficulty)}',
                            ],
                          ),
                        ),
                      ],
                    ]
                  : [
                      Expanded(
                        child: _Cell(
                          label: 'Best',
                          value: bests[ramp]!,
                          color: game.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Cell(
                          label: 'Played',
                          value: app.plays(game, ramp),
                          color: LS.text,
                          showZero: true,
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.color,
    this.notes = const [],
    this.showZero = false,
  });

  final String label;
  final int value;
  final Color color;
  final List<String> notes;

  /// Show "0" instead of "—" (counts rather than scores).
  final bool showZero;

  @override
  Widget build(BuildContext context) {
    final empty = value == 0 && !showZero;
    return Container(
      color: LS.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, size: 10, color: LS.dim),
          const SizedBox(height: 4),
          Text(
            empty ? '—' : '$value',
            style: LSText.mono(
              19,
              weight: FontWeight.w700,
              spacing: 0,
              color: empty ? LS.dim : color,
            ),
          ),
          for (final note in notes) ...[
            const SizedBox(height: 2),
            MonoLabel(note, size: 10, color: LS.dim),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.run});

  final RunRecord run;

  @override
  Widget build(BuildContext context) {
    final game = run.game;
    return ChamferBox(
      cut: Cut.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GameTile(game: game, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.titleWith(run.difficulty),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LSText.body(15, weight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 3),
                MonoLabel(formatAgo(run.playedAt), size: 10, color: LS.dim),
              ],
            ),
          ),
          if (run.isBest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              color: LS.blue,
              child: const MonoLabel(
                'Best',
                size: 10,
                weight: FontWeight.w700,
                color: LS.bg,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (game.tracksTime) ...[
            MonoLabel(formatDuration(run.duration), size: 10, color: LS.dim),
            const SizedBox(width: 10),
          ],
          Text(
            '${run.score}',
            style: LSText.mono(
              17,
              weight: FontWeight.w700,
              spacing: 0,
              color: LS.text,
            ),
          ),
        ],
      ),
    );
  }
}
