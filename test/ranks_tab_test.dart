import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/screens/ranks_tab.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/network.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_leaderboard_api.dart';

// Rocket Launch has a single board (ramp difficulty) and no run times.
const _game = GameId.rocketLaunch;
const _difficulty = GameId.rampDifficulty;

Map<String, dynamic> _row(String id, String name, int score, String bestAt) => {
  'player_id': id,
  'player_name': name,
  'score': score,
  'game_type': _game.name,
  'difficulty': _difficulty.name,
  'duration_ms': null,
  'best_at': bestAt,
};

// Local times, so the expected labels don't depend on the test machine.
final _day1 = [
  _row('a', 'AXON', 980, '2026-09-10T08:00:00'),
  _row('b', 'BOLT', 900, '2026-09-12T13:00:00'),
  _row('c', 'CYAN', 800, '2026-09-11T09:00:00'),
];

// CYAN climbs, BOLT falls, the player ("me") enters at #4 from #14.
final _day2 = [
  _row('a', 'AXON', 980, '2026-09-10T08:00:00'),
  _row('c', 'CYAN', 950, '2026-09-13T13:00:00'),
  _row('b', 'BOLT', 900, '2026-09-12T13:00:00'),
  _row('me', 'NEON', 870, '2026-09-09T20:02:00'),
];

class _Harness {
  _Harness(this.storage, this.api, this.network);

  final Storage storage;
  final FakeLeaderboardApi api;
  final Network network;
  final tabs = NavTabs();
  DateTime now = DateTime(2026, 9, 12, 15);
  late final leaderboard = Leaderboard(storage, api: api, now: () => now);

  /// Switch away and back, as the player does.
  Future<void> reopenRanks(WidgetTester tester) async {
    tabs.value = NavTabs.play;
    tabs.value = NavTabs.ranks;
    await tester.pump();
    await tester.pump();
  }

  /// A new day where the board changed.
  void nextDay() {
    api
      ..rows = _day2
      ..rank = 4;
    now = DateTime(2026, 9, 13, 15);
  }
}

Future<_Harness> _setUp({bool online = true}) async {
  SharedPreferences.setMockInitialValues({'playerName': 'NEON'});
  final storage = Storage(await SharedPreferences.getInstance());
  return _Harness(
    storage,
    FakeLeaderboardApi(rows: _day1, rank: 14),
    Network.fixed(online),
  );
}

Future<void> _pump(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState(h.storage)),
        ChangeNotifierProvider.value(value: h.tabs),
        ChangeNotifierProvider.value(value: h.leaderboard),
        Provider.value(value: Ads()),
        Provider.value(value: h.network),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: RanksTab()),
      ),
    ),
  );
  h.tabs.value = NavTabs.ranks;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first look: dates, pinned row, no movement chips', (
    tester,
  ) async {
    final h = await _setUp();
    await _pump(tester, h);

    expect(find.text('UPDATED TODAY, 3:00 PM'), findsOneWidget);
    expect(find.text('#1 SINCE SEP 10'), findsOneWidget);
    expect(find.text('2 H AGO'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('NEW'), findsNothing);
    expect(find.textContaining('▲'), findsNothing);
    // Outside the Top 10: pinned under the list.
    expect(find.text('#14'), findsOneWidget);
    expect(find.text('YOUR BEST'), findsOneWidget);
    expect(find.text('REFRESH'), findsOneWidget);
  });

  testWidgets('a changed board: chips, dates and the climb banner', (
    tester,
  ) async {
    final h = await _setUp();
    await _pump(tester, h);
    h.nextDay();
    await h.reopenRanks(tester);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('YOU CLIMBED 10 PLACES'), findsOneWidget);
    expect(find.text('WAS #14 · INTO THE TOP 10'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('YOU CLIMBED 10 PLACES'), findsNothing, reason: 'hides');
    expect(find.text('▲1'), findsOneWidget); // CYAN
    expect(find.text('▼1'), findsOneWidget); // BOLT
    expect(find.text('NEW'), findsOneWidget); // the player
    expect(find.text('950'), findsOneWidget, reason: 'counted up to');
    expect(find.text('#1 SINCE SEP 10'), findsOneWidget);
    expect(find.text('2 H AGO'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('SEP 9'), findsOneWidget);
    expect(find.text('#14'), findsNothing, reason: 'now in the list');
    expect(find.text('UPDATED TODAY, 3:00 PM'), findsOneWidget);
  });

  testWidgets('reduced motion: the final state and chips at once', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final h = await _setUp();
    await _pump(tester, h);
    h.nextDay();
    await h.reopenRanks(tester);

    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('▲1'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('950'), findsOneWidget);
    expect(find.text('YOU CLIMBED 10 PLACES'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget, reason: 'rank ticker at the end');
  });

  testWidgets('a free refresh (no ad ready) starts the 5 min cooldown', (
    tester,
  ) async {
    final h = await _setUp();
    await _pump(tester, h);

    await tester.tap(find.text('REFRESH'));
    await tester.pumpAndSettle();
    expect(h.api.topCalls, hasLength(2));
    expect(find.text('REFRESH IN 5:00'), findsOneWidget);
  });

  testWidgets('offline: no ad action, the saved board, restored online', (
    tester,
  ) async {
    final h = await _setUp(online: false);
    await h.leaderboard.load(_game, _difficulty);
    await _pump(tester, h);

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('REFRESH'), findsNothing);
    expect(find.text('OFFLINE — SHOWING SAVED SCORES.'), findsOneWidget);
    expect(find.text('AXON'), findsOneWidget);
    expect(h.api.topCalls, hasLength(1), reason: 'no server call offline');

    h.network.online.value = true;
    await tester.pumpAndSettle();
    expect(find.text('OFFLINE'), findsNothing);
    expect(find.text('REFRESH'), findsOneWidget);
    expect(find.text('UPDATED TODAY, 3:00 PM'), findsOneWidget);
  });
}
