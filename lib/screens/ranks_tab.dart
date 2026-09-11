import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'name_sheet.dart';

/// One global Top 10 at a time: pick a game (and a difficulty for games that
/// have them). Opens on the game you last played. Your own position is
/// pinned below the list when you're outside the Top 10.
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

  static const _shortTitles = {
    GameId.rocketLaunch: 'Rocket',
    GameId.memoryLane: 'Memory',
    GameId.quickMath: 'Math',
    GameId.guessColor: 'Color',
  };

  Difficulty get _boardDifficulty =>
      _game.hasDifficulty ? _difficulty : GameId.rampDifficulty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = context.read<NavTabs>();
    if (!identical(tabs, _tabs)) {
      _tabs?.removeListener(_onTabChange);
      _tabs = tabs..addListener(_onTabChange);
      _onTabChange();
    }
  }

  // Each time the tab opens, jump to the last played board and load it
  // (cheap: served from the day-long cache).
  void _onTabChange() {
    if (_tabs?.value != NavTabs.ranks) {
      return;
    }
    final last = context.read<AppState>().lastPlayed;
    if (last != null) {
      _game = last.$1;
      _difficulty = last.$2;
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

  Future<void> _refresh({bool force = false}) async {
    final game = _game;
    final difficulty = _boardDifficulty;
    setState(() => _loading = true);
    final load = await context.read<Leaderboard>().load(
      game,
      difficulty,
      refresh: force,
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

  Future<void> _chooseName() async {
    if (await showNameSheet(context) && mounted) {
      await _refresh();
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChange);
    super.dispose();
  }

  String get _subtitle {
    final load = _load;
    if (load?.message != null) {
      return load!.message!;
    }
    final at = load?.updatedAt;
    return at == null
        ? _game.titleWith(_boardDifficulty)
        : 'Updated ${formatAgo(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final leaderboard = context.watch<Leaderboard>();
    final app = context.watch<AppState>();
    final me = leaderboard.playerId;
    final name = leaderboard.savedName;
    final entries = _load?.entries ?? const <LeaderboardEntry>[];
    final myRank = _load?.myRank;
    final timed = _game.tracksTime;
    final inList = me != null && entries.any((e) => e.playerId == me);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DisplayText('Global Top 10', size: 30),
                    const SizedBox(height: 5),
                    MonoLabel(_subtitle),
                  ],
                ),
              ),
              LSIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                color: LS.muted,
                onPressed: _loading ? null : () => _refresh(force: true),
              ),
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
          child: _loading && _load == null
              ? const Center(
                  child: CircularProgressIndicator(
                    color: LS.teal,
                    strokeWidth: 2,
                  ),
                )
              : entries.isEmpty
              ? _Empty(game: _game)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => _RankRow(
                    rank: i + 1,
                    name: entries[i].playerName,
                    score: entries[i].score,
                    time: timed ? entries[i].duration : null,
                    isYou: me != null && entries[i].playerId == me,
                  ),
                ),
        ),
        if (name == null)
          _JoinBar(onTap: _chooseName)
        else if (myRank != null && !inList)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _RankRow(
              rank: myRank,
              name: name,
              score: app.best(_game, _boardDifficulty),
              time: timed ? app.bestTime(_game, _boardDifficulty) : null,
              isYou: true,
            ),
          ),
      ],
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

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.time,
    required this.isYou,
  });

  final int rank;
  final String name;
  final int score;

  /// Only for games that track time (Memory Lane, Quick Math).
  final Duration? time;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final highlight = rank == 1 ? LS.blue : (isYou ? LS.teal : null);
    final time = this.time;
    return ChamferBox(
      cut: Cut.sm,
      height: 56,
      color: highlight?.withValues(alpha: 0.06) ?? LS.surface,
      borderColor: highlight?.withValues(alpha: 0.55) ?? LS.line,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rank > 10 ? '#$rank' : '$rank'.padLeft(2, '0'),
                style: LSText.mono(
                  16,
                  weight: FontWeight.w700,
                  spacing: 0,
                  color: rank == 1 ? LS.blue : (isYou ? LS.teal : LS.muted),
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LSText.body(
                      16,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                if (isYou) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    color: LS.teal,
                    child: const MonoLabel(
                      'You',
                      size: 10,
                      weight: FontWeight.w700,
                      color: LS.bg,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (time != null) ...[
            MonoLabel(formatDuration(time), size: 10, color: LS.dim),
            const SizedBox(width: 12),
          ],
          Text(
            '$score',
            style: LSText.mono(
              18,
              weight: FontWeight.w700,
              spacing: 0,
              color: highlight ?? LS.text,
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
