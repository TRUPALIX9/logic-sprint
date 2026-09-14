import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../models/leaderboard_entry.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/network.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'name_sheet.dart';
import 'ranks/rank_board.dart';
import 'ranks/rank_row.dart';
import 'ranks/refresh_action.dart';

/// One global Top 10 at a time: pick a game (and a difficulty for games that
/// have them). Opens on the game you last played. Your own position is
/// pinned below the list when you're outside the Top 10.
///
/// Boards update on the first visit of each day and after a new best, and
/// animate what changed since you last looked (see [RankBoard]). "Refresh ▶"
/// fetches now after a rewarded ad (free, with a longer cooldown, when no ad
/// is ready). Offline there are no ads: the action is replaced by "Offline"
/// and the saved board is shown.
class RanksTab extends StatefulWidget {
  const RanksTab({super.key});

  @override
  State<RanksTab> createState() => _RanksTabState();
}

class _RanksTabState extends State<RanksTab> {
  LeaderboardLoad? _load;
  bool _loading = false;
  GameId _game = GameId.rocketLaunch;
  Difficulty _difficulty = Difficulty.easy;
  NavTabs? _tabs;
  Network? _network;

  static const _shortTitles = {
    GameId.rocketLaunch: 'Rocket',
    GameId.memoryLane: 'Memory',
    GameId.quickMath: 'Math',
    GameId.guessColor: 'Color',
  };

  Difficulty get _boardDifficulty =>
      _game.hasDifficulty ? _difficulty : GameId.rampDifficulty;

  bool get _online => _network?.online.value ?? true;

  bool get _visible => _tabs?.value == NavTabs.ranks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final network = context.read<Network>();
    if (!identical(network, _network)) {
      _network?.online.removeListener(_onNetworkChange);
      _network = network..online.addListener(_onNetworkChange);
    }
    final tabs = context.read<NavTabs>();
    if (!identical(tabs, _tabs)) {
      _tabs?.removeListener(_onTabChange);
      _tabs = tabs..addListener(_onTabChange);
      _onTabChange();
    }
  }

  // Each time the tab opens, jump to the last played board and load it
  // (cheap: served from today's cache).
  void _onTabChange() {
    if (!_visible) {
      return;
    }
    final last = context.read<AppState>().lastPlayed;
    if (last != null) {
      _game = last.$1;
      _difficulty = last.$2;
    }
    if (_online) {
      context.read<Ads>().preloadRefreshRewarded();
    }
    _refresh();
  }

  // Going offline shows the saved board with a notice; coming back clears
  // it (and fetches if the board is out of date).
  void _onNetworkChange() {
    if (!mounted || !_visible) {
      return;
    }
    if (_online) {
      context.read<Ads>().preloadRefreshRewarded();
    }
    _refresh();
  }

  void _select({GameId? game, Difficulty? difficulty}) {
    setState(() {
      _game = game ?? _game;
      _difficulty = difficulty ?? _difficulty;
      _load = null;
    });
    _refresh();
  }

  Future<void> _refresh({bool force = false, bool rewarded = false}) async {
    final game = _game;
    final difficulty = _boardDifficulty;
    setState(() => _loading = true);
    final load = await context.read<Leaderboard>().load(
      game,
      difficulty,
      refresh: force,
      rewarded: rewarded,
      offline: !_online,
    );
    // Ignore answers for a board the user already switched away from.
    if (!mounted || game != _game || difficulty != _boardDifficulty) {
      return;
    }
    setState(() {
      _load = load;
      _loading = false;
    });
  }

  /// "Refresh ▶": a rewarded ad, then a refresh. Without a ready ad the
  /// refresh is free (the leaderboard applies the longer cooldown).
  void _refreshNow() {
    if (!_online) {
      return;
    }
    final ads = context.read<Ads>();
    if (ads.refreshRewardedReady.value) {
      ads.showRefreshRewarded(
        onReward: () {
          if (mounted) {
            _refresh(force: true, rewarded: true);
          }
        },
        onDone: () {},
      );
    } else {
      _refresh(force: true);
    }
  }

  Future<void> _chooseName() async {
    if (await showNameSheet(context) && mounted) {
      await _refresh();
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChange);
    _network?.online.removeListener(_onNetworkChange);
    super.dispose();
  }

  String _subtitle(DateTime now) {
    final load = _load;
    if (load?.message != null) {
      return load!.message!;
    }
    final at = load?.updatedAt;
    return at == null
        ? _game.titleWith(_boardDifficulty)
        : 'Updated ${formatDayTime(at, now: now)}';
  }

  /// When the player's best on this board was set, from local History.
  DateTime? _bestSetAt(Leaderboard leaderboard, int best) => leaderboard.history
      .where(
        (r) =>
            r.game == _game &&
            r.difficulty == _boardDifficulty &&
            r.score == best,
      )
      .lastOrNull // History is newest first: the first time it was reached.
      ?.playedAt;

  @override
  Widget build(BuildContext context) {
    final leaderboard = context.watch<Leaderboard>();
    final app = context.watch<AppState>();
    final ads = context.read<Ads>();
    final network = context.read<Network>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final now = leaderboard.now();
    final load = _load;
    final me = leaderboard.playerId;
    final name = leaderboard.savedName;
    final entries = load?.entries ?? const <LeaderboardEntry>[];
    final myRank = load?.myRank;
    final timed = _game.tracksTime;
    final inList = me != null && entries.any((e) => e.playerId == me);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: DisplayText('Global Top 10', size: 30, maxLines: 1),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: network.online,
                    builder: (context, online, _) => online
                        ? RefreshAction(
                            wait: leaderboard.refreshWait,
                            adReady: ads.refreshRewardedReady,
                            busy: _loading,
                            onPressed: _refreshNow,
                          )
                        : const SizedBox(
                            height: 44,
                            child: Center(
                              widthFactor: 1,
                              child: MonoLabel(
                                'Offline',
                                weight: FontWeight.w700,
                                color: LS.dim,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              MonoLabel(_subtitle(now)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Segments<GameId>(
            options: [
              for (final game in GameId.values) (game, _shortTitles[game]!),
            ],
            selected: _game,
            accentOf: (game) => game.accent,
            onSelect: (game) => _select(game: game),
          ),
        ),
        if (_game.hasDifficulty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Segments<Difficulty>(
              options: [for (final d in Difficulty.values) (d, d.label)],
              selected: _difficulty,
              accentOf: (_) => _game.accent,
              onSelect: (d) => _select(difficulty: d),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: _loading && load == null
              ? const Center(
                  child: CircularProgressIndicator(
                    color: LS.teal,
                    strokeWidth: 2,
                  ),
                )
              : entries.isEmpty
              ? _Empty(game: _game)
              : RankBoard(
                  key: ObjectKey(load),
                  load: load!,
                  me: me,
                  timed: timed,
                  now: now,
                  reduceMotion: reduceMotion,
                  haptics: app.vibrationOn,
                ),
        ),
        if (name == null)
          _JoinBar(onTap: _chooseName)
        else if (load != null && myRank != null && !inList)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _pinnedRow(
              load: load,
              myRank: myRank,
              name: name,
              best: app.best(_game, _boardDifficulty),
              time: timed ? app.bestTime(_game, _boardDifficulty) : null,
              setAt: _bestSetAt(leaderboard, app.best(_game, _boardDifficulty)),
              now: now,
              reduceMotion: reduceMotion,
            ),
          ),
      ],
    );
  }

  /// Your row under the list; its rank ticks from the old one on a change.
  Widget _pinnedRow({
    required LeaderboardLoad load,
    required int myRank,
    required String name,
    required int best,
    required Duration? time,
    required DateTime? setAt,
    required DateTime now,
    required bool reduceMotion,
  }) {
    final from = load.previousMyRank;
    final tick =
        load.changed && load.previous != null && from != null && !reduceMotion;
    return TweenAnimationBuilder<int>(
      key: ObjectKey(load),
      tween: IntTween(begin: tick ? from : myRank, end: myRank),
      duration: tick ? const Duration(milliseconds: 1200) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, rank, _) => RankRow(
        rank: rank,
        name: name,
        score: best,
        time: time,
        isYou: true,
        detail: setAt == null
            ? 'Your best'
            : 'Your best · set ${formatWhen(setAt, now: now)}',
      ),
    );
  }
}

/// Equal-width segmented picker, 44 px tall.
class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.options,
    required this.selected,
    required this.accentOf,
    required this.onSelect,
  });

  final List<(T, String)> options;
  final T selected;
  final Color Function(T value) accentOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      cut: Cut.sm,
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(value),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    color: value == selected
                        ? accentOf(value).withValues(alpha: 0.16)
                        : null,
                    child: MonoLabel(
                      label,
                      weight: FontWeight.w700,
                      color: value == selected ? accentOf(value) : LS.dim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pinned under the board until the player has a display name.
class _JoinBar extends StatelessWidget {
  const _JoinBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ChamferBox(
        cut: Cut.sm,
        color: LS.teal.withValues(alpha: 0.06),
        borderColor: LS.teal.withValues(alpha: 0.55),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            const Icon(
              Icons.person_add_alt_1_rounded,
              color: LS.teal,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Choose a name to appear here',
                style: LSText.body(14, color: LS.muted, height: 1.2),
              ),
            ),
            CardAction(label: 'Set name', onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.game});

  final GameId game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 40, color: game.accent),
            const SizedBox(height: 12),
            Text(
              'No scores yet.\nPlay ${game.title} to set the first one.',
              textAlign: TextAlign.center,
              style: LSText.body(15, color: LS.muted),
            ),
          ],
        ),
      ),
    );
  }
}
