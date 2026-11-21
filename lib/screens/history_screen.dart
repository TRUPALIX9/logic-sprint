import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/game.dart';
import '../models/history_query.dart';
import '../models/run_record.dart';
import '../services/leaderboard.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';
import 'profile/history_row.dart';

/// Every run kept on this device. The run count for the current filters
/// sits at the top right; a sort menu and swipeable filter chips (All, then
/// one per game, then Easy/Medium/Hard for games that have them) sit above
/// the list. No Best summary: Profile already shows the bests.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen());

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  var _query = const HistoryQuery();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<Leaderboard>().history;
    final runs = _query.apply(history);
    final game = _query.game;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LSTopBar(
              title: 'History',
              trailing: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _RunCount(count: runs.length),
              ),
            ),
            if (history.isEmpty)
              const Expanded(child: _NoRunsYet())
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: MonoLabel(
                        'On this device only',
                        size: 10,
                        color: LS.dim,
                      ),
                    ),
                    _SortButton(
                      sort: _query.sort,
                      onSelected: (sort) =>
                          setState(() => _query = _query.withSort(sort)),
                    ),
                  ],
                ),
              ),
              _ChipRow(
                key: const ValueKey('history-games'),
                chips: [
                  LSChip(
                    label: 'All',
                    selected: game == null,
                    onTap: () => setState(() => _query = _query.withGame(null)),
                  ),
                  for (final g in GameId.values)
                    LSChip(
                      label: g.title,
                      accent: g.accent,
                      selected: game == g,
                      onTap: () => setState(() => _query = _query.withGame(g)),
                    ),
                ],
              ),
              AnimatedSize(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: game != null && game.hasDifficulty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ChipRow(
                          key: ValueKey('history-levels-${game.name}'),
                          chips: [
                            LSChip(
                              label: 'All levels',
                              accent: game.accent,
                              selected: _query.difficulty == null,
                              onTap: () => setState(
                                () => _query = _query.withDifficulty(null),
                              ),
                            ),
                            for (final d in Difficulty.values)
                              LSChip(
                                label: d.label,
                                accent: game.accent,
                                selected: _query.difficulty == d,
                                onTap: () => setState(
                                  () => _query = _query.withDifficulty(
                                    _query.difficulty == d ? null : d,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: runs.isEmpty
                    ? _NoMatches(query: _query)
                    : _RunList(runs: runs),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "140 RUNS" with the number in full white.
class _RunCount extends StatelessWidget {
  const _RunCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final style = LSText.mono(12, color: LS.muted, weight: FontWeight.w500);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '$count',
            style: style.copyWith(color: LS.text, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: count == 1 ? ' RUN' : ' RUNS'),
        ],
      ),
    );
  }
}

/// Sort icon with the current order as its label; opens a small chamfered
/// menu of the four orders.
class _SortButton extends StatefulWidget {
  const _SortButton({required this.sort, required this.onSelected});

  final HistorySort sort;
  final ValueChanged<HistorySort> onSelected;

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(LS.surface),
        shape: WidgetStatePropertyAll(chamfer(Cut.sm, border: LS.line)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4),
        ),
      ),
      menuChildren: [
        for (final sort in HistorySort.values)
          Semantics(
            selected: sort == widget.sort,
            child: MenuItemButton(
              onPressed: () => widget.onSelected(sort),
              style: MenuItemButton.styleFrom(
                minimumSize: const Size(200, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              leadingIcon: SizedBox(
                width: 20,
                child: sort == widget.sort
                    ? const Icon(Icons.check_rounded, size: 18, color: LS.teal)
                    : null,
              ),
              child: Text(
                sort.label,
                style: LSText.body(
                  15,
                  weight: FontWeight.w600,
                  color: sort == widget.sort ? LS.teal : LS.text,
                ),
              ),
            ),
          ),
      ],
      child: Tooltip(
        message: 'Sort runs',
        excludeFromSemantics: true,
        child: Semantics(
          label: 'Sort runs',
          child: ChamferBox(
            cut: Cut.sm,
            height: 44,
            borderColor: null,
            color: LS.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert_rounded, size: 18, color: LS.teal),
                const SizedBox(width: 6),
                MonoLabel(
                  widget.sort.label,
                  size: 12,
                  weight: FontWeight.w700,
                  color: LS.teal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of chips that scrolls sideways with a swipe. It runs to the
/// screen edges (no clipping inside the page margin) with 20 px padding,
/// and shows no scroll bar.
class _ChipRow extends StatelessWidget {
  const _ChipRow({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    );
  }
}

class _RunList extends StatelessWidget {
  const _RunList({required this.runs});

  final List<RunRecord> runs;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('history-runs'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: runs.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: HistoryRow(run: runs[i]),
        );
      },
    );
  }
}

/// Nothing played on this device yet.
class _NoRunsYet extends StatelessWidget {
  const _NoRunsYet();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DisplayText('No runs yet', size: 24),
          const SizedBox(height: 8),
          Text(
            'Finished runs show up here.',
            textAlign: TextAlign.center,
            style: LSText.body(15, color: LS.muted),
          ),
        ],
      ),
    ),
  );
}

/// The filters match nothing: "No Line Split runs yet".
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final HistoryQuery query;

  @override
  Widget build(BuildContext context) {
    final game = query.game;
    final difficulty = query.difficulty;
    final level = difficulty == null
        ? ''
        : ' ${difficulty.label[0]}${difficulty.label.substring(1).toLowerCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        game == null ? 'No runs yet' : 'No ${game.title}$level runs yet',
        textAlign: TextAlign.center,
        style: LSText.body(15, color: LS.muted),
      ),
    );
  }
}
