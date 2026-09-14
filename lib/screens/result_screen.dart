import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../games/games.dart';
import '../models/round_result.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/network.dart';
import '../state/app_state.dart';
import '../ui/ad_banner.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'name_sheet.dart';

/// [synced] completes with whether the run reached the server; null means
/// it already has.
Route<void> resultRoute(RoundResult result, {Future<bool>? synced}) =>
    MaterialPageRoute<void>(
      builder: (_) => ResultScreen(result: result, synced: synced),
    );

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result, this.synced});

  final RoundResult result;
  final Future<bool>? synced;

  @override
  Widget build(BuildContext context) {
    final game = result.game;
    return Scaffold(
      body: SafeArea(
        child: _TopBanner(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          GameTile(game: game, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const DisplayText('Game over', size: 26),
                                const SizedBox(height: 4),
                                MonoLabel(game.titleWith(result.difficulty)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _ScoreCard(result: result)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat(
                              'Correct',
                              '${result.correct}',
                              LS.teal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: game.tracksTime
                                ? _Stat(
                                    'Time',
                                    formatDuration(result.duration),
                                    LS.text,
                                  )
                                : _Stat(
                                    'Best',
                                    '${math.max(result.score, result.previousBest)}',
                                    LS.text,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SyncCard(result: result, synced: synced),
                      const _HeartAdCard(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Home',
                              onPressed: () => Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Play again',
                              icon: Icons.refresh_rounded,
                              onPressed: () =>
                                  Navigator.of(context).pushReplacement(
                                    gameRoute(game, result.difficulty),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The run's heart ad: every finished run unlocks one rewarded ad worth a
/// heart. Hidden offline (ad-free), when used, when hearts are full, or
/// when no ad is loaded.
class _HeartAdCard extends StatefulWidget {
  const _HeartAdCard();

  @override
  State<_HeartAdCard> createState() => _HeartAdCardState();
}

class _HeartAdCardState extends State<_HeartAdCard> {
  bool _watching = false;

  void _watch() {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _watching = true);
    context.read<Ads>().showRewarded(
      onReward: () async {
        await app.earnHeart();
        messenger.showSnackBar(
          SnackBar(content: Text('+1 heart · you have ${app.hearts}')),
        );
        if (mounted) {
          setState(() => _watching = false);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _watching = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ads = context.read<Ads>();
    final network = context.read<Network>();
    return ListenableBuilder(
      listenable: Listenable.merge([ads.rewardedReady, network.online]),
      builder: (context, _) {
        if (!network.online.value ||
            !ads.rewardedReady.value ||
            !app.canEarnHeart) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ChamferBox(
            borderColor: LS.coral.withValues(alpha: 0.4),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: LS.coral),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DisplayText('Earn a heart', size: 18),
                      const SizedBox(height: 4),
                      MonoLabel(
                        'Revive any run · you have ${app.hearts}',
                        size: 10,
                        color: LS.dim,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CardAction(
                  label: _watching ? 'Loading…' : '▶ Watch ad',
                  onTap: _watching ? () {} : _watch,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A banner above the result, far from the Home / Play again buttons at the
/// bottom (every run of every game ends here).
class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AdBanner(padding: EdgeInsets.only(top: 8)),
        Expanded(child: child),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result});

  final RoundResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.game.accent;
    return ChamferBox(
      cut: Cut.lg,
      borderColor: accent.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MonoLabel('Score'),
          const SizedBox(height: 12),
          Text(
            '${result.score}',
            style:
                LSText.mono(
                  88,
                  color: accent,
                  weight: FontWeight.w700,
                  spacing: 0,
                ).copyWith(
                  height: 1,
                  shadows: [
                    Shadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          if (result.isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: LS.blue,
              child: MonoLabel(
                'New best · +${result.improvement}',
                size: 12,
                weight: FontWeight.w700,
                color: LS.bg,
              ),
            )
          else
            MonoLabel(
              'Best ${math.max(result.score, result.previousBest)}',
              color: LS.dim,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, size: 10, color: LS.dim),
          const SizedBox(height: 6),
          Text(
            value,
            style: LSText.mono(
              22,
              color: color,
              weight: FontWeight.w700,
              spacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Sync { offline, noName, ranked, unranked }

/// Where the run went. Every run is saved automatically: this shows the
/// global rank, the offline state, or an invite to choose a name.
class _SyncCard extends StatefulWidget {
  const _SyncCard({required this.result, required this.synced});

  final RoundResult result;
  final Future<bool>? synced;

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  late Future<(_Sync, int?)> _status;

  @override
  void initState() {
    super.initState();
    _status = _check();
  }

  Future<(_Sync, int?)> _check() async {
    final leaderboard = context.read<Leaderboard>();
    final result = widget.result;
    if (!await (widget.synced ?? Future.value(true))) {
      return (_Sync.offline, null);
    }
    if (leaderboard.savedName == null) {
      return (_Sync.noName, null);
    }
    final rank = (await leaderboard.load(
      result.game,
      result.difficulty,
    )).myRank;
    return rank == null ? (_Sync.unranked, null) : (_Sync.ranked, rank);
  }

  Future<void> _chooseName() async {
    if (await showNameSheet(context) && mounted) {
      setState(() => _status = _check());
    }
  }

  void _seeRanks() {
    final tabs = context.read<NavTabs>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    tabs.value = NavTabs.ranks;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return FutureBuilder(
      future: _status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final (icon, title, detail, action) = switch (status?.$1) {
          null => (null, 'Saving run', 'Syncing your best', null),
          _Sync.offline => (
            Icons.cloud_off_rounded,
            'Saved on this phone',
            'Offline — will sync later',
            null,
          ),
          _Sync.noName => (
            Icons.person_add_alt_1_rounded,
            'Join the Global Top 10',
            'Choose a name once',
            CardAction(label: 'Set name', onTap: _chooseName),
          ),
          _Sync.ranked => (
            Icons.check_rounded,
            result.isNewBest ? 'New best · saved' : 'Run saved',
            'Global rank #${status!.$2} · '
                '${result.game.titleWith(result.difficulty)}',
            CardAction(label: 'Ranks', onTap: _seeRanks),
          ),
          _Sync.unranked => (
            Icons.check_rounded,
            'Run saved',
            result.score == 0
                ? 'Score above 0 to get a rank'
                : 'Rank updates soon',
            null,
          ),
        };
        return ChamferBox(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: icon == null
                    ? const Padding(
                        padding: EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LS.teal,
                        ),
                      )
                    : Icon(
                        icon,
                        color: status?.$1 == _Sync.offline ? LS.muted : LS.teal,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DisplayText(title, size: 18, maxLines: 1),
                    const SizedBox(height: 4),
                    MonoLabel(detail, size: 10, color: LS.dim),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 8), action],
            ],
          ),
        );
      },
    );
  }
}
