import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/games/round_screen.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/network.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_leaderboard_api.dart';

/// A bare run the test drives by hand: no timers, no board.
class _TestEngine extends RoundEngine {
  _TestEngine({super.feedback, super.previousBest})
    : super(game: GameId.quickMath, difficulty: Difficulty.easy);

  // `this.` so it isn't flutter_test's top-level fail().
  void miss() => this.fail();
}

/// One frame; an animation completes on the first frame past its end.
const _frame = Duration(milliseconds: 16);

void main() {
  late _TestEngine engine;
  late Network network;

  /// Pumps a RoundScreen inside the real app providers. [hearts] are in the
  /// wallet; no rewarded ad ever loads in tests.
  Future<void> pumpRound(
    WidgetTester tester, {
    bool online = true,
    int hearts = 2,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'hearts': hearts});
    final storage = Storage(await SharedPreferences.getInstance());
    network = Network.fixed(online);
    await tester.pumpWidget(
      LogicSprintApp(
        appState: AppState(storage),
        leaderboard: Leaderboard(storage, api: FakeLeaderboardApi()),
        ads: Ads(),
        network: network,
        version: '1.0.0 (1)',
        home: RoundScreen<_TestEngine>(
          game: GameId.quickMath,
          difficulty: Difficulty.easy,
          createEngine: (feedback, best) =>
              engine = _TestEngine(feedback: feedback, previousBest: best),
          builder: (context, engine) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(engine.state, RunState.playing);
  }

  Finder text(String pattern) =>
      find.textContaining(RegExp(pattern, caseSensitive: false));

  final roundScreen = find.byWidgetPredicate((w) => w is RoundScreen);

  /// Goes down with [score] points.
  Future<void> goDown(WidgetTester tester, {int score = 100}) async {
    engine
      ..score = score
      ..miss();
    await tester.pump();
  }

  testWidgets('online with a heart: the offer shows and the heart revives', (
    tester,
  ) async {
    await pumpRound(tester);
    await goDown(tester);
    expect(text('2 left'), findsOneWidget);
    expect(text('watch ad'), findsNothing, reason: 'no ad loaded in tests');

    await tester.tap(text('2 left'));
    await tester.pump();
    await tester.pump();
    expect(engine.state, RunState.resuming, reason: 'get ready first');
    expect(engine.revives, 1);
    expect(text('left'), findsNothing);
    expect(text('get ready'), findsOneWidget);
    await tester.pump(); // the countdown's first frame
    await tester.pump(GetReady.duration + _frame);
    expect(engine.state, RunState.playing);
    await tester.pump();
    expect(text('get ready'), findsNothing);
  });

  /// Down, then revived with a heart: the get-ready countdown is showing.
  Future<void> reviveWithHeart(WidgetTester tester) async {
    await goDown(tester);
    await tester.tap(text('2 left'));
    await tester.pump();
    await tester.pump();
    await tester.pump(); // the countdown's first frame
  }

  testWidgets('get ready counts 3 · 2 · 1, then the run goes on', (
    tester,
  ) async {
    await pumpRound(tester);
    await tester.pump(const Duration(seconds: 1));
    final before = engine.elapsed;
    await reviveWithHeart(tester);
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 990));
    expect(engine.state, RunState.resuming);
    expect(engine.elapsed, before, reason: 'the countdown is not run time');
    await tester.pump(const Duration(milliseconds: 26));
    expect(engine.state, RunState.playing);
  });

  testWidgets('leaving the app during get ready restarts it from 3', (
    tester,
  ) async {
    await pumpRound(tester);
    await reviveWithHeart(tester);
    await tester.pump(const Duration(seconds: 2));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 30));
    expect(engine.state, RunState.resuming, reason: 'held while away');
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(engine.state, RunState.resuming, reason: 'a full 3 s again');
    await tester.pump(const Duration(milliseconds: 116));
    expect(engine.state, RunState.playing);
  });

  testWidgets('below the minimum score the run just ends', (tester) async {
    await pumpRound(tester);
    await goDown(tester, score: 40);
    expect(text('left'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
    expect(roundScreen, findsNothing);
  });

  testWidgets('offline: no offer at all and the run ends', (tester) async {
    await pumpRound(tester, online: false, hearts: 5);
    await goDown(tester, score: 500);
    expect(text('left'), findsNothing);
    expect(text('watch ad'), findsNothing);
    expect(engine.state, RunState.down);
    await tester.pump(const Duration(milliseconds: 700));
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
    expect(roundScreen, findsNothing);
  });

  testWidgets('losing the connection while the offer is up ends the run', (
    tester,
  ) async {
    await pumpRound(tester);
    await goDown(tester);
    expect(text('2 left'), findsOneWidget);
    network.online.value = false;
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
    expect(roundScreen, findsNothing);
  });

  testWidgets('the offer auto-declines after 5 s', (tester) async {
    await pumpRound(tester);
    await goDown(tester);
    await tester.pump(const Duration(milliseconds: 4900));
    expect(engine.state, RunState.down);
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
    expect(roundScreen, findsNothing);
  });

  testWidgets('leaving the app holds the offer; returning restarts 5 s', (
    tester,
  ) async {
    await pumpRound(tester);
    await goDown(tester);
    await tester.pump(const Duration(seconds: 3));

    // Lifecycle states must change one step at a time.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 30));
    expect(engine.state, RunState.down, reason: 'held while away');

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(milliseconds: 4900));
    expect(engine.state, RunState.down, reason: 'a full 5 s again');
    expect(text('2 left'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('leaving the app pauses; only Resume continues', (tester) async {
    await pumpRound(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(engine.state, RunState.paused);
    expect(text('^paused\$'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(engine.state, RunState.paused, reason: 'no auto-resume');

    await tester.tap(text('^resume\$'));
    await tester.pump();
    expect(engine.state, RunState.playing);
    expect(text('^paused\$'), findsNothing);
  });

  testWidgets('the bar is || and the score; || turns into resume', (
    tester,
  ) async {
    await pumpRound(tester);
    expect(text(GameId.quickMath.title), findsNothing);
    expect(find.byTooltip('Quit round'), findsNothing, reason: 'no back');
    expect(text('^score\$'), findsOneWidget);
    expect(text('^0\$'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(engine.state, RunState.paused);
    expect(find.byTooltip('Pause'), findsNothing);

    // The bar's resume stays reachable above the paused card.
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(engine.state, RunState.playing);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets("the phone's back button pauses instead of quitting", (
    tester,
  ) async {
    await pumpRound(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(engine.state, RunState.paused);
    expect(roundScreen, findsOneWidget);
  });

  testWidgets('back pauses; back again saves the run and goes home', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'hearts': 0});
    final storage = Storage(await SharedPreferences.getInstance());
    final app = AppState(storage);
    await tester.pumpWidget(
      LogicSprintApp(
        appState: app,
        leaderboard: Leaderboard(storage, api: FakeLeaderboardApi()),
        ads: Ads(),
        network: Network.fixed(true),
        version: '1.0.0 (1)',
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RoundScreen<_TestEngine>(
                    game: GameId.quickMath,
                    difficulty: Difficulty.easy,
                    createEngine: (feedback, best) => engine = _TestEngine(
                      feedback: feedback,
                      previousBest: best,
                    ),
                    builder: (context, engine) => const SizedBox.expand(),
                  ),
                ),
              ),
              child: const Text('HOME'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    engine.score = 40;

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(engine.state, RunState.paused);
    expect(roundScreen, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(engine.isFinished, isTrue);
    expect(roundScreen, findsNothing);
    expect(find.text('HOME'), findsOneWidget, reason: 'home, no Result');
    expect(app.best(GameId.quickMath, Difficulty.easy), 40);
  });

  testWidgets('the pause button pauses; End run finishes', (tester) async {
    await pumpRound(tester);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(engine.state, RunState.paused);

    await tester.tap(text('end run'));
    await tester.pump();
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
    expect(roundScreen, findsNothing);
  });

  testWidgets('a 4th revive is never offered', (tester) async {
    await pumpRound(tester, hearts: 5);
    for (var i = 0; i < 3; i++) {
      await goDown(tester);
      expect(text('left'), findsOneWidget);
      await tester.tap(text('left'));
      await tester.pump();
      await tester.pump();
      expect(engine.revives, i + 1);
      await tester.pump();
      await tester.pump(GetReady.duration + _frame);
      expect(engine.state, RunState.playing);
    }
    await goDown(tester);
    expect(engine.canRevive, isFalse);
    expect(text('left'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(engine.isFinished, isTrue);
    await tester.pumpAndSettle();
  });
}
