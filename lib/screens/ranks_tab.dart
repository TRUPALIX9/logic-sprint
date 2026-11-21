import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

/// One global Top 10 at a time: step through games with ‹ › (or swipe), and
/// pick a difficulty underneath for games that have them. Opens on the game
/// you last played. The picker shows one game at a time, so it fits any
/// number of games. Your own position is
/// pinned below the list when you're outside the Top 10.
///
/// Every board updates once a day, for everyone, at 00:00 UTC: the header
/// shows when they were fetched and counts down to the next update. Your own
/// new bests show up on your board right away (and go to the server);
/// "Refresh ▶" plays a rewarded interstitial and then pulls everyone's
/// latest scores now, with a cooldown after.
/// Boards animate what changed since you last looked (see [RankBoard]).
/// Offline, the saved board is shown.
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
  Timer? _resetTimer;

  /// Which way the last switch went (−1 previous, 1 next, 0 difficulty), so
  /// the new board slides in from that side.
  int _direction = 0;

  /// The board on screen was switched to by the player: animate it in and
  /// count its scores up.
  bool _switched = false;

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
    _switched = false;
    if (_online) {
      context.read<Ads>().preloadRefresh();
    }
    _refresh();
  }

  // Going offline shows the saved board with a notice; coming back clears
  // it (and fetches if 00:00 UTC has passed).
  void _onNetworkChange() {
    if (!mounted || !_visible) {
      return;
    }
    if (_online) {
      context.read<Ads>().preloadRefresh();
    }
    _refresh();
  }

  void _select({GameId? game, Difficulty? difficulty, int direction = 0}) {
    if ((game ?? _game) == _game &&
        (difficulty ?? _difficulty) == _difficulty) {
      return;
    }
    setState(() {
      _game = game ?? _game;
      _difficulty = difficulty ?? _difficulty;
      _direction = direction;
      _switched = true;
      _load = null;
    });
    _refresh();
  }

  /// ‹ or › (or a swipe): the previous or next game, wrapping around.
  void _step(int delta) {
    const games = GameId.values;
    final next = games[(games.indexOf(_game) + delta) % games.length];
    context.read<AppState>().tap();
    _select(game: next, direction: delta.sign);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 250) {
      _step(velocity < 0 ? 1 : -1);
    }
  }

  Future<void> _refresh({bool now = false}) async {
    final game = _game;
    final difficulty = _boardDifficulty;
    setState(() => _loading = true);
    final load = await context.read<Leaderboard>().load(
      game,
      difficulty,
      offline: !_online,
      refresh: now,
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

  /// 00:00 UTC passed while the app is open: only a visible Ranks tab
  /// fetches (a hidden one does on its next open), after a random delay so
  /// open devices don't all hit the server in the same second.
  void _onReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(seconds: Random().nextInt(60)), () {
      if (mounted && _visible) {
        _refresh();
      }
    });
  }

  /// "Refresh ▶": an intro with an opt-out (required before a rewarded
  /// interstitial), the ad, then everyone's latest scores.
  Future<void> _refreshNow() async {
    if (!_online) {
      return;
    }
    final watch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LS.surface,
        shape: chamfer(Cut.lg, border: LS.line),
        title: const DisplayText('Refresh now?', size: 24),
        content: Text(
          'Watch a short ad to get everyone’s latest scores now instead of '
          'at 00:00 UTC.',
          style: LSText.body(15, color: LS.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const MonoLabel('No thanks', weight: FontWeight.w700),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const MonoLabel(
              'Watch ad',
              weight: FontWeight.w700,
              color: LS.teal,
            ),
          ),
        ],
      ),
    );
    if (watch != true || !mounted) {
      return;
    }
    _switched = false;
    context.read<Ads>().showRefresh(
      onReward: () {
        if (mounted) {
          _refresh(now: true);
        }
      },
      onDone: () {},
    );
  }

  /// Long-press on another player's row: confirm, then report the name.
  Future<void> _report(LeaderboardEntry entry) async {
    final leaderboard = context.read<Leaderboard>();
    final messenger = ScaffoldMessenger.of(context);
    final report = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LS.surface,
        shape: chamfer(Cut.lg, border: LS.line),
        title: const DisplayText('Report name?', size: 24),
        content: Text(
          'Report ${entry.playerName} as offensive? Names reported by several '
          'players are hidden from the leaderboard.',
          style: LSText.body(15, color: LS.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const MonoLabel('Cancel', weight: FontWeight.w700),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const MonoLabel(
              'Report',
              weight: FontWeight.w700,
              color: LS.coral,
            ),
          ),
        ],
      ),
    );
    if (report != true) {
      return;
    }
    final sent = await leaderboard.reportName(entry.playerId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Thanks — ${entry.playerName} was reported'
              : 'Couldn’t reach the server. Try again later.',
        ),
      ),
    );
  }

  Future<void> _chooseName() async {
    if (await showNameSheet(context) && mounted) {
      await _refresh();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _tabs?.removeListener(_onTabChange);
    _network?.online.removeListener(_onNetworkChange);
    super.dispose();
  }

  String _subtitle(DateTime now) {
    final load = _load;
    if (load?.message != null) {
      return load!.message!;
    }
    final at = context.read<Leaderboard>().fetchedAt;
    return at == null
        ? 'Updates daily at 00:00 UTC'
        : 'Updated ${formatDayTime(at, now: now)} · daily 00:00 UTC';
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
    final network = context.read<Network>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final now = leaderboard.now();
    final load = _load;
    final me = leaderboard.playerId;
    final name = leaderboard.displayName;
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
                        ? _RefreshButton(
                            wait: leaderboard.refreshWait,
                            adReady: context.read<Ads>().refreshReady,
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
              if (_online) ...[
                const SizedBox(height: 4),
                _NextUpdate(now: leaderboard.now, onReset: _onReset),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _GamePicker(
            game: _game,
            direction: _direction,
            reduceMotion: reduceMotion,
            onStep: _step,
            onSwipe: _onSwipe,
          ),
        ),
        // Difficulty tabs only for games that have them; single-board games
        // show nothing here, and the board slides up smoothly.
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _game.hasDifficulty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _Segments<Difficulty>(
                    options: [for (final d in Difficulty.values) (d, d.label)],
                    selected: _difficulty,
                    accentOf: (_) => _game.accent,
                    onSelect: (d) => _select(difficulty: d),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: _onSwipe,
            child: _SlideSwitcher(
              expand: true,
              boardKey: ValueKey((_game, _boardDifficulty)),
              direction: _direction,
              reduceMotion: reduceMotion,
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
                      countUp: _switched,
                      haptics: app.vibrationOn,
                      onReport: _online ? _report : null,
                    ),
            ),
          ),
        ),
        if (name == null)
          _JoinBar(onTap: _chooseName)
        // Your own best always sits under the Top 10 when you're not in it,
        // ranked or not yet ranked (a first or new best outside the Top 10
        // gets its number at the next daily refresh).
        else if (load != null &&
            !inList &&
            (myRank != null || app.best(_game, _boardDifficulty) > 0))
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
  /// Without a rank yet it shows "—" and says when the rank arrives.
  Widget _pinnedRow({
    required LeaderboardLoad load,
    required int? myRank,
    required String name,
    required int best,
    required Duration? time,
    required DateTime? setAt,
    required DateTime now,
    required bool reduceMotion,
  }) {
    if (myRank == null) {
      return RankRow(
        rank: null,
        name: name,
        score: best,
        time: time,
        isYou: true,
        detail: 'Your best · ranked after 00:00 UTC',
      );
    }
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

/// ‹ Game ›: one game at a time with its icon, name and colour, arrows on
/// both sides (44 pt targets), swipe on the name, and a dot per game.
class _GamePicker extends StatelessWidget {
  const _GamePicker({
    required this.game,
    required this.direction,
    required this.reduceMotion,
    required this.onStep,
    required this.onSwipe,
  });

  final GameId game;
  final int direction;
  final bool reduceMotion;
  final ValueChanged<int> onStep;
  final GestureDragEndCallback onSwipe;

  @override
  Widget build(BuildContext context) {
    const games = GameId.values;
    final index = games.indexOf(game);
    final motion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return Column(
      children: [
        Row(
          children: [
            _Arrow(
              icon: Icons.chevron_left_rounded,
              label: 'Previous game',
              onTap: () => onStep(-1),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: onSwipe,
                child: Semantics(
                  liveRegion: true,
                  label: '${game.title}, ${index + 1} of ${games.length}',
                  excludeSemantics: true,
                  child: ChamferBox(
                    cut: Cut.sm,
                    height: 52,
                    borderColor: null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 3,
                          child: AnimatedContainer(
                            duration: motion,
                            color: game.accent,
                          ),
                        ),
                        Center(
                          child: _SlideSwitcher(
                            boardKey: ValueKey(game),
                            direction: direction,
                            reduceMotion: reduceMotion,
                            distance: 0.35,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GameTile(game: game, size: 28),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: DisplayText(game.title, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _Arrow(
              icon: Icons.chevron_right_rounded,
              label: 'Next game',
              onTap: () => onStep(1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final g in games)
              AnimatedContainer(
                duration: motion,
                width: g == game ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                color: g == game ? g.accent : LS.line,
              ),
          ],
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: ChamferBox(
          cut: Cut.sm,
          width: 44,
          height: 52,
          color: LS.surface2,
          borderColor: null,
          onTap: onTap,
          child: Icon(icon, color: LS.text, size: 26),
        ),
      ),
    );
  }
}

/// Cross-fades to a new [child] whenever [boardKey] changes, sliding the new
/// one in from the side the player moved toward ([direction] 1 = next,
/// −1 = previous, 0 = straight fade) and the old one out the other way.
class _SlideSwitcher extends StatelessWidget {
  const _SlideSwitcher({
    required this.boardKey,
    required this.direction,
    required this.reduceMotion,
    required this.child,
    this.distance = 0.18,
    this.expand = false,
  });

  /// Children fill the space (the board) instead of keeping their own size
  /// (the name strip).
  final bool expand;
  final Key boardKey;
  final int direction;
  final bool reduceMotion;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final incoming = child.key == boardKey;
        final from = Offset(distance * direction * (incoming ? 1 : -1), 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: from, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        fit: expand ? StackFit.expand : StackFit.loose,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: boardKey, child: child),
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

/// "Next update 7h 12m" until the next 00:00 UTC; ticks every 20 s and calls
/// [onReset] once the reset passes (the tab then fetches the new boards).
class _NextUpdate extends StatefulWidget {
  const _NextUpdate({required this.now, required this.onReset});

  final DateTime Function() now;
  final VoidCallback onReset;

  @override
  State<_NextUpdate> createState() => _NextUpdateState();
}

class _NextUpdateState extends State<_NextUpdate> {
  late DateTime _next = Leaderboard.nextReset(widget.now());
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!widget.now().isBefore(_next)) {
        _next = Leaderboard.nextReset(widget.now());
        widget.onReset();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _next.difference(widget.now());
    final hours = left.inHours;
    final minutes = left.inMinutes.remainder(60).clamp(0, 59);
    final label = hours > 0 ? '${hours}h ${minutes}m' : '${max(minutes, 1)}m';
    return Semantics(
      label: 'Next update for everyone in $label',
      excludeSemantics: true,
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 13, color: LS.teal),
          const SizedBox(width: 5),
          MonoLabel(
            'Next update $label',
            size: 10,
            weight: FontWeight.w700,
            color: LS.teal,
          ),
        ],
      ),
    );
  }
}

/// "Refresh ▶" in the Ranks header: plays the rewarded interstitial, then
/// pulls everyone's latest scores. Disabled until the ad has loaded; during
/// the cooldown it reads "Refresh in 28m" and ticks (only this widget
/// rebuilds).
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({
    required this.wait,
    required this.adReady,
    required this.busy,
    required this.onPressed,
  });

  /// Remaining cooldown (zero when a refresh is allowed).
  final Duration Function() wait;
  final ValueListenable<bool> adReady;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.wait() > Duration.zero) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (widget.wait() <= Duration.zero) {
          _ticker?.cancel();
          _ticker = null;
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wait = widget.wait();
    final cooling = wait > Duration.zero;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.adReady,
      builder: (context, ad, _) {
        final enabled = !cooling && ad && !widget.busy;
        final label = cooling
            ? 'Refresh in ${wait > const Duration(minutes: 1) ? '${(wait.inSeconds / 60).ceil()}m' : '${(wait.inMilliseconds / 1000).ceil()}s'}'
            : 'Refresh';
        final icon = cooling
            ? Icons.timer_outlined
            : (ad ? Icons.play_circle_outline_rounded : Icons.hourglass_empty);
        final color = enabled ? LS.teal : LS.dim;
        return Semantics(
          button: true,
          enabled: enabled,
          label: cooling
              ? label
              : (ad ? 'Refresh now, watch an ad' : 'Refresh, ad loading'),
          excludeSemantics: true,
          child: ChamferBox(
            cut: Cut.sm,
            height: 44,
            borderColor: null,
            color: LS.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: enabled ? widget.onPressed : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MonoLabel(label, weight: FontWeight.w700, color: color),
                const SizedBox(width: 6),
                Icon(icon, size: 18, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}
