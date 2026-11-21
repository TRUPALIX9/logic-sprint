import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../games/games.dart';
import '../models/game.dart';
import '../state/app_state.dart';
import '../ui/brand.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'game_sheet.dart';
import 'hearts_sheet.dart';
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
                _HeartsChip(
                  hearts: app.hearts,
                  onTap: () => showHeartsSheet(context),
                ),
                const SizedBox(width: 4),
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
        // The game grid (two per row) stretches to fill the screen; on short
        // screens it keeps its natural height, scrolls, and says how many
        // games are below.
        const Expanded(child: _GameGrid()),
        // Pinned at the bottom, just above the ad, so the last game is one
        // thumb tap away.
        if (last != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: _JumpBackIn(
              game: last.$1,
              difficulty: last.$2,
              best: app.best(last.$1, last.$2),
            ),
          ),
      ],
    );
  }
}

/// Title plus the two-per-row game grid. When some games don't fit on the
/// screen, a "+N more" chip with a down arrow sits at the bottom edge; a tap
/// scrolls down to them.
class _GameGrid extends StatefulWidget {
  const _GameGrid();

  @override
  State<_GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<_GameGrid> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  late final List<GlobalKey> _rows = [
    for (var k = 0; k < GameId.values.length; k += 2) GlobalKey(),
  ];

  /// Games whose card is mostly below the visible area.
  int _hidden = 0;

  static List<List<GameId>> get _pairs => [
    for (var k = 0; k < GameId.values.length; k += 2)
      GameId.values.sublist(k, math.min(k + 2, GameId.values.length)),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    final view = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (view == null || !view.hasSize) {
      return;
    }
    final bottom = view.size.height;
    var hidden = 0;
    for (final (i, key) in _rows.indexed) {
      final row = key.currentContext?.findRenderObject() as RenderBox?;
      if (row == null || !row.hasSize) {
        continue;
      }
      final top = row.localToGlobal(Offset.zero, ancestor: view).dy;
      // Hidden when less than half the row shows.
      if (top + row.size.height / 2 > bottom) {
        hidden += _pairs[i].length;
      }
    }
    if (hidden != _hidden && mounted) {
      setState(() => _hidden = hidden);
    }
  }

  void _showMore() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final end = _scroll.position.maxScrollExtent;
    if (reduceMotion) {
      _scroll.jumpTo(end);
    } else {
      _scroll.animateTo(
        end,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _measure();
        return false;
      },
      child: Stack(
        key: _viewport,
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                // No bottom padding here: SliverFillRemaining would ignore it
                // and push the last row under the nav bar (spacer below).
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DisplayText('Ready to sprint?', size: 28),
                      const SizedBox(height: 14),
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
                      // Two cards per row for any number of games; an odd
                      // last game spans the row.
                      for (final (i, pair) in _pairs.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Expanded(
                          key: _rows[i],
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 124),
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: _hidden == 0
                    ? const SizedBox.shrink()
                    : _MoreChip(count: _hidden, onTap: _showMore),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "+2 more ↓": tells the player more games are below and scrolls to them.
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count more games below',
      excludeSemantics: true,
      child: ChamferBox(
        key: ValueKey(count),
        cut: Cut.sm,
        height: 44,
        color: LS.surface2,
        borderColor: LS.teal.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MonoLabel(
              '+$count more',
              size: 12,
              weight: FontWeight.w700,
              color: LS.teal,
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: LS.teal,
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart count in the header; opens the Hearts sheet.
class _HeartsChip extends StatelessWidget {
  const _HeartsChip({required this.hearts, required this.onTap});

  final int hearts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$hearts hearts',
      excludeSemantics: true,
      child: ChamferBox(
        cut: Cut.sm,
        height: 44,
        borderColor: null,
        color: LS.surface2,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, size: 18, color: LS.coral),
            const SizedBox(width: 6),
            Text(
              '$hearts',
              style: LSText.mono(
                15,
                weight: FontWeight.w700,
                spacing: 0,
                color: LS.text,
              ),
            ),
          ],
        ),
      ),
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
          // Compact enough that all six games fit above the pinned
          // "Jump back in" card on a regular phone.
          GameTile(game: game, size: 38),
          const Spacer(),
          DisplayText(game.title, size: 19, maxLines: 2),
          const SizedBox(height: 6),
          MonoLabel(game.skill, size: 10),
          const SizedBox(height: 4),
          MonoLabel(
            best > 0 ? 'Best $best' : 'Not played',
            size: 11,
            weight: FontWeight.w700,
            color: best > 0 ? game.accent : LS.dim,
          ),
        ],
      ),
    );
  }
}
