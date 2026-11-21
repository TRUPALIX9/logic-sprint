import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/history_query.dart';
import 'package:logic_sprint/models/run_record.dart';
import 'package:logic_sprint/screens/history_screen.dart';
import 'package:logic_sprint/screens/profile/history_row.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/ui/kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_leaderboard_api.dart';

RunRecord _run(
  GameId game,
  int score,
  Duration ago, {
  Difficulty difficulty = GameId.rampDifficulty,
  bool best = false,
}) => RunRecord(
  game: game,
  difficulty: difficulty,
  score: score,
  duration: const Duration(seconds: 40),
  playedAt: DateTime.now().subtract(ago),
  isBest: best,
);

/// Five runs, newest first: Quick Math 15 min ago, then Angle Sense Hard
/// (a new best), Rocket Launch, Angle Sense Easy and Memory Lane.
List<RunRecord> _runs() => [
  _run(
    GameId.quickMath,
    120,
    const Duration(minutes: 15),
    difficulty: Difficulty.easy,
  ),
  _run(
    GameId.angleSense,
    212,
    const Duration(hours: 2),
    difficulty: Difficulty.hard,
    best: true,
  ),
  _run(GameId.rocketLaunch, 5140, const Duration(hours: 30)),
  _run(
    GameId.angleSense,
    90,
    const Duration(days: 3),
    difficulty: Difficulty.easy,
  ),
  _run(
    GameId.memoryLane,
    460,
    const Duration(days: 5),
    difficulty: Difficulty.medium,
  ),
];

Future<void> _pumpHistory(WidgetTester tester, {List<RunRecord>? runs}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = Storage(await SharedPreferences.getInstance());
  // Storage keeps newest first: add oldest first.
  for (final run in (runs ?? _runs()).reversed) {
    await storage.addHistory(run);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: Leaderboard(storage, api: FakeLeaderboardApi()),
      child: MaterialApp(theme: buildTheme(), home: const HistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scores of the rows on screen, top to bottom.
List<int> _shown(WidgetTester tester) => [
  for (final row in tester.widgetList<HistoryRow>(find.byType(HistoryRow)))
    row.run.score,
];

Finder _chip(String label) => find.widgetWithText(LSChip, label);

Finder _chipScrollable(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(Scrollable),
);

Future<void> _tapGameChip(WidgetTester tester, String label) =>
    _tapChip(tester, label, row: 'history-games');

Future<void> _tapLevel(WidgetTester tester, String label) =>
    _tapChip(tester, label, row: 'history-levels-angleSense');

/// Swipes [row] until the chip is on screen, then taps it.
Future<void> _tapChip(
  WidgetTester tester,
  String label, {
  required String row,
}) async {
  final scrollable = _chipScrollable(row);
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(_chip(label), 120, scrollable: scrollable);
  await tester.ensureVisible(_chip(label));
  await tester.pumpAndSettle();
  await tester.tap(_chip(label));
  await tester.pumpAndSettle();
}

/// Loads the bundled fonts so chip widths match a device.
Future<void> _loadFonts() async {
  const families = {
    'Rajdhani': ['Rajdhani-SemiBold', 'Rajdhani-Bold'],
    'IBMPlexSans': [
      'IBMPlexSans-Regular',
      'IBMPlexSans-Medium',
      'IBMPlexSans-SemiBold',
    ],
    'JetBrainsMono': ['JetBrainsMono-Medium', 'JetBrainsMono-Bold'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  group('History page', () {
    testWidgets('title, run count top right, newest first, no Best summary', (
      tester,
    ) async {
      await _pumpHistory(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('HISTORY'), findsOneWidget);
      final count = find.text('5 RUNS', findRichText: true);
      expect(count, findsOneWidget);
      // Top right: level with the title, past the middle of the screen.
      final width = tester.view.physicalSize.width / 3;
      expect(tester.getTopRight(count).dx, greaterThan(width - 40));
      expect(
        (tester.getCenter(count).dy - tester.getCenter(find.text('HISTORY')).dy)
            .abs(),
        lessThan(12),
      );

      expect(_shown(tester), [120, 212, 5140, 90, 460]);
      expect(find.text('Quick Math · EASY'), findsOneWidget);
      expect(find.text('15 MIN AGO'), findsOneWidget);
      expect(find.text('5,140'), findsOneWidget);

      // The only "best" is the badge on the run that set one: no summary.
      final best = find.textContaining(RegExp('best', caseSensitive: false));
      expect(best, findsOneWidget);
      expect(
        find.ancestor(of: best, matching: find.byType(HistoryRow)),
        findsOneWidget,
      );
    });

    testWidgets('sort menu: every order, current one shown as the label', (
      tester,
    ) async {
      await _pumpHistory(tester);
      expect(find.text('NEWEST'), findsOneWidget);
      expect(find.byTooltip('Sort runs'), findsOneWidget);

      for (final (sort, scores) in [
        (HistorySort.highest, [5140, 460, 212, 120, 90]),
        (HistorySort.lowest, [90, 120, 212, 460, 5140]),
        (HistorySort.oldest, [460, 90, 5140, 212, 120]),
        (HistorySort.newest, [120, 212, 5140, 90, 460]),
      ]) {
        await tester.tap(find.byTooltip('Sort runs'));
        await tester.pumpAndSettle();
        // The menu lists all four orders.
        for (final s in HistorySort.values) {
          expect(find.text(s.label), findsOneWidget);
        }
        await tester.tap(find.text(sort.label));
        await tester.pumpAndSettle();
        expect(_shown(tester), scores, reason: sort.label);
        expect(find.text(sort.label.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('filter by game, then by difficulty', (tester) async {
      await _pumpHistory(tester);
      // Ramp games have no level row.
      await _tapGameChip(tester, 'ROCKET LAUNCH');
      expect(_shown(tester), [5140]);
      expect(find.text('1 RUN', findRichText: true), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-levels-rocketLaunch')),
        findsNothing,
      );

      await _tapGameChip(tester, 'ANGLE SENSE');
      expect(_shown(tester), [212, 90]);
      expect(find.text('2 RUNS', findRichText: true), findsOneWidget);
      // Angle Sense has levels: a second row appears.
      expect(
        find.byKey(const ValueKey('history-levels-angleSense')),
        findsOneWidget,
      );
      await _tapLevel(tester, 'HARD');
      expect(_shown(tester), [212]);
      await _tapLevel(tester, 'EASY');
      expect(_shown(tester), [90]);
      await _tapLevel(tester, 'MEDIUM');
      expect(_shown(tester), isEmpty);
      expect(find.text('No Angle Sense Medium runs yet'), findsOneWidget);
      expect(find.text('0 RUNS', findRichText: true), findsOneWidget);

      // Sort and filter combine.
      await _tapLevel(tester, 'ALL LEVELS');
      await tester.tap(find.byTooltip('Sort runs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lowest score'));
      await tester.pumpAndSettle();
      expect(_shown(tester), [90, 212]);

      // Back to All: the level row goes away.
      await _tapGameChip(tester, 'ALL');
      expect(
        find.byKey(const ValueKey('history-levels-angleSense')),
        findsNothing,
      );
      expect(_shown(tester), hasLength(5));
    });

    testWidgets('chips: swipe sideways, full width, 44 pt, selected state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpHistory(tester);
      final width = tester.view.physicalSize.width / 3;
      final row = find.byKey(const ValueKey('history-games'));

      // The row runs edge to edge; chips start at the 20 pt margin.
      expect(tester.getSize(row).width, width);
      expect(tester.getTopLeft(_chip('ALL')).dx, 20);
      expect(
        find.descendant(of: row, matching: find.byType(Scrollbar)),
        findsNothing,
      );
      final all = tester.getSize(_chip('ALL'));
      expect(all.height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(_chip('ALL')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(_chip('ROCKET LAUNCH')),
        isSemantics(isSelected: false),
      );

      // All + six games don't fit: the last chip starts off screen.
      final lineSplit = _chip('LINE SPLIT');
      expect(
        lineSplit.evaluate().isEmpty ||
            tester.getTopLeft(lineSplit).dx >= width,
        isTrue,
      );

      // A swipe brings it in.
      await tester.drag(row, const Offset(-600, 0));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(_chipScrollable('history-games'))
          .position;
      expect(position.pixels, greaterThan(0));
      await tester.drag(row, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.getTopRight(lineSplit).dx, lessThanOrEqualTo(width));
      expect(tester.getTopLeft(lineSplit).dx, greaterThanOrEqualTo(0));
      // In the game's accent.
      final label = tester.widget<Text>(
        find.descendant(of: lineSplit, matching: find.byType(Text)),
      );
      expect(label.style?.color, GameId.lineSplit.accent);

      await tester.tap(lineSplit);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(lineSplit), isSemantics(isSelected: true));
      expect(find.text('No Line Split runs yet'), findsOneWidget);
      expect(find.text('0 RUNS', findRichText: true), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('no runs at all', (tester) async {
      await _pumpHistory(tester, runs: []);
      expect(find.text('NO RUNS YET'), findsOneWidget);
      expect(find.text('0 RUNS', findRichText: true), findsOneWidget);
      expect(find.byType(LSChip), findsNothing);
      expect(find.byType(HistoryRow), findsNothing);
    });

    testWidgets('every run is kept and counted', (tester) async {
      await _pumpHistory(
        tester,
        runs: [
          for (var i = 0; i < 250; i++)
            _run(GameId.quickMath, i, Duration(minutes: i)),
        ],
      );
      expect(find.text('250 RUNS', findRichText: true), findsOneWidget);
      expect(find.textContaining('keeps your last'), findsNothing);
    });
  });

  group('HistoryQuery', () {
    test('equal scores keep the newer run first', () {
      final runs = [
        _run(GameId.quickMath, 50, const Duration(minutes: 1)),
        _run(GameId.quickMath, 50, const Duration(minutes: 2)),
        _run(GameId.quickMath, 10, const Duration(minutes: 3)),
      ];
      for (final sort in [HistorySort.highest, HistorySort.lowest]) {
        final sorted = HistoryQuery(sort: sort).apply(runs);
        final fifties = sorted.where((r) => r.score == 50).toList();
        expect(fifties.first, same(runs[0]), reason: sort.label);
      }
    });

    test('picking a game clears the difficulty; ramp games ignore it', () {
      const query = HistoryQuery(
        game: GameId.angleSense,
        difficulty: Difficulty.hard,
      );
      expect(query.withGame(GameId.angleSense).difficulty, Difficulty.hard);
      expect(query.withGame(GameId.quickMath).difficulty, isNull);
      final ramp = const HistoryQuery(
        game: GameId.rocketLaunch,
      ).withDifficulty(Difficulty.easy);
      expect(ramp.matches(_run(GameId.rocketLaunch, 1, Duration.zero)), isTrue);
    });
  });
}
