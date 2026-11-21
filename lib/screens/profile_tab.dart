import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/profile_stats.dart';
import '../models/run_record.dart';
import '../services/leaderboard.dart';
import '../services/stats_share.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import '../ui/sprint_gauge.dart';
import 'history_screen.dart';
import 'name_sheet.dart';
import 'profile/history_row.dart';
import 'profile/stat_text.dart';

/// Profile, top to bottom: name and code, the Sprint Score gauge, each
/// game's best (once), the latest runs (opens History), then one Share
/// button at the bottom. No wordmark. Run and play-time totals are hidden
/// for now (still in [ProfileStats]).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.sharer = const StatsSharer()});

  /// Renders and shares the stats image (swappable in tests).
  final StatsSharer sharer;

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final leaderboard = context.watch<Leaderboard>();
    final stats = profileStats(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        const DisplayText('Profile', size: 30),
        const SizedBox(height: 16),
        _NameRow(stats: stats),
        const SizedBox(height: 14),
        _ScoreTile(top: stats.sprintTop),
        const SizedBox(height: 22),
        const MonoLabel('Your bests'),
        const SizedBox(height: 10),
        for (final game in stats.games)
          Padding(
            key: ValueKey('best-${game.game.name}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: _BestRow(stat: game),
          ),
        const SizedBox(height: 22),
        _HistoryPreview(history: leaderboard.history),
        const SizedBox(height: 22),
        _ShareButton(stats: stats, sharer: sharer),
      ],
    );
  }
}

/// The last few runs and a way into the full History page.
class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.history});

  final List<RunRecord> history;

  /// Runs shown here; History has the rest.
  static const shown = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const MonoLabel('History'),
            const Spacer(),
            CardAction(
              label: 'See all',
              onTap: () => Navigator.of(context).push(HistoryScreen.route()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Text(
            'Finished runs show up here.',
            style: LSText.body(15, color: LS.muted),
          )
        else
          for (final run in history.take(shown))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: HistoryRow(run: run),
            ),
      ],
    );
  }
}

/// The player's stats from local bests, plays, History and cached ranks.
ProfileStats profileStats(BuildContext context) {
  final app = context.read<AppState>();
  final leaderboard = context.read<Leaderboard>();
  final tag = leaderboard.savedTag;
  return ProfileStats.from(
    name: leaderboard.savedName,
    tag: tag == null ? null : Leaderboard.formatTag(tag),
    best: app.best,
    bestTime: app.bestTime,
    plays: app.plays,
    rank: leaderboard.cachedRank,
    history: leaderboard.history,
    sprintTop: leaderboard.cachedSprintTop,
  );
}

/// NEON_FOX#0420 with an Edit action. No wordmark on Profile.
class _NameRow extends StatelessWidget {
  const _NameRow({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final name = stats.name;
    return Row(
      children: [
        Expanded(
          child: name == null
              ? Text(
                  'Set a name to show on the boards',
                  style: LSText.body(15, color: LS.muted),
                )
              : NameWithTag(name: name, tag: stats.tag, size: 28),
        ),
        const SizedBox(width: 8),
        CardAction(
          label: name == null ? 'Set name' : 'Edit',
          onTap: () => showNameSheet(context),
        ),
      ],
    );
  }
}

/// The Sprint Score gauge on its own full-width panel.
class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.top});

  final int? top;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      borderColor: null,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: SprintGauge(
            top: top,
            diameter: constraints.maxWidth.clamp(0, 220).toDouble(),
          ),
        ),
      ),
    );
  }
}

/// One game: icon, title, E/M/H bests (when they fit on one line, else the
/// difficulty and rank of the best) and the best in the game's accent.
class _BestRow extends StatelessWidget {
  const _BestRow({required this.stat});

  final GameStat stat;

  @override
  Widget build(BuildContext context) {
    final game = stat.game;
    final metaStyle = LSText.mono(10, spacing: 0.04);
    return ChamferBox(
      cut: Cut.sm,
      borderColor: null,
      // Accent edge as a positioned bar: the subtitle's LayoutBuilder rules
      // out IntrinsicHeight here.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 12, 8),
            child: Row(
              children: [
                GameTile(game: game, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DisplayText(game.title, size: 16, maxLines: 1),
                      const SizedBox(height: 3),
                      LayoutBuilder(
                        builder: (context, constraints) => Text(
                          _subtitle(context, metaStyle, constraints.maxWidth),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                BestText(stat: stat, size: 17),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: game.accent),
          ),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context, TextStyle style, double width) {
    final breakdown = difficultyBreakdown(stat);
    if (breakdown != null) {
      final painter = TextPainter(
        text: TextSpan(text: breakdown, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = painter.width <= width;
      painter.dispose();
      if (fits) {
        return breakdown;
      }
    }
    return gameMeta(stat);
  }
}

/// One Share button straight to the system share sheet, where the player
/// picks the app. A note under it says the link is copied too.
class _ShareButton extends StatefulWidget {
  const _ShareButton({required this.stats, required this.sharer});

  final ProfileStats stats;
  final StatsSharer sharer;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _busy = false;

  Future<void> _share() async {
    // Anchors the system sheet on iPad.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await widget.sharer.send(widget.stats, origin: origin);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text("Couldn't share right now. Try again.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PrimaryButton(
        label: _busy ? 'Preparing…' : 'Share',
        icon: Icons.ios_share_rounded,
        onPressed: _busy ? null : _share,
      ),
      const SizedBox(height: 8),
      Text(
        linkCopiedNote,
        textAlign: TextAlign.center,
        style: LSText.body(12, color: LS.dim, height: 1.4),
      ),
    ],
  );
}
