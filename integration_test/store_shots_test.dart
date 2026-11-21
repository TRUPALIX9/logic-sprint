// Opens Ranks and Profile with seeded 1.1 data (six games, a fictional
// player, a fake Top 10 dated today) and holds each screen long enough for
// `xcrun simctl io <udid> screenshot`. Ads never initialise and the
// leaderboard is the in-memory fake, so nothing reaches AdMob or Supabase.
//
//   flutter test integration_test/store_shots_test.dart -d <udid>
// Watch the log for SHOT_MARK lines and take the screenshot while it holds.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/run_record.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fake_leaderboard_api.dart';

/// (game, medium best, plays, best time ms or null)
const _bests = [
  ('rocketLaunch', 3930, 41, null),
  ('memoryLane', 210, 12, 61000),
  ('quickMath', 380, 37, 44000),
  ('guessColor', 260, 15, null),
  ('angleSense', 310, 9, null),
  ('lineSplit', 240, 7, null),
];

final _prefs = <String, Object>{
  for (final (g, best, plays, time) in _bests) ...{
    'highScore_${g}_medium': best,
    'plays_${g}_medium': plays,
    'bestTime_${g}_medium': ?time,
  },
  'playerName': 'NEON_FOX',
  'playerTag': 420,
  'rocketShip': 'rocket',
  'hearts': 3,
};

const _players = [
  'AXON#1187',
  'NEON_FOX#0420',
  'SYNAPSE_9#3918',
  'KIRA-X#0649',
  'BITWISE#5380',
  'LUMEN#2203',
  'DENDRITE#9075',
  'PIXEL_OWL#4466',
  'QUARK#0812',
  'VECTOR#3371',
];

final _today = DateTime.now().toUtc();

/// A Top 10 per game; NEON_FOX#0420 ("me") sits at #2 on each.
final _ranks = [
  for (final (game, best, _, time) in _bests)
    for (final (i, name) in _players.indexed)
      {
        'player_id': name == 'NEON_FOX#0420' ? 'me' : 'p$i',
        'player_name': name,
        'score': name == 'NEON_FOX#0420'
            ? best
            : (best * (1.12 - i * 0.07)).round() ~/ 10 * 10,
        'game_type': game,
        'difficulty': 'medium',
        'duration_ms': time ?? (90 + i * 7) * 1000,
        'best_at': _today
            .subtract(Duration(minutes: 20 + i * 37))
            .toIso8601String(),
      },
];

Future<void> _hold(String scene, int ms) async {
  debugPrint('SHOT_MARK $scene');
  await Future.delayed(Duration(milliseconds: ms));
}

/// A finger on the screen, sent as device input like a real touch (the test
/// binding draws a crosshair over test-dispatched pointers; this one shows
/// nothing). Same as store_demo_test.dart.
class _Touch {
  _Touch(Offset at) : _at = at, _pointer = _nextPointer++ {
    _send(PointerDownEvent(pointer: _pointer, position: at));
  }

  static int _nextPointer = 1000;
  final int _pointer;
  Offset _at;

  void moveTo(Offset at) {
    _send(PointerMoveEvent(pointer: _pointer, position: at, delta: at - _at));
    _at = at;
  }

  void up() => _send(PointerUpEvent(pointer: _pointer, position: _at));

  static void _send(PointerEvent event) =>
      TestWidgetsFlutterBinding.instance.handlePointerEventForSource(
        event,
        source: TestBindingEventSource.device,
      );
}

/// Scenes, picked with `--dart-define=SCENE=name`:
///   (none)        Home, Ranks, Profile (top, scrolled), Rocket Launch
///   game title    that game's first question ("Guess Color", "Angle Sense"…)
///   Line Split    one deliberate miss, to show how close the guess was
///   Revive        a Rocket Launch run that crashes and offers a heart
const _scene = String.fromEnvironment('SCENE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store shots', (tester) async {
    binding.shouldPropagateDevicePointerEvents = true;
    SharedPreferences.setMockInitialValues({
      ..._prefs,
      // A low best, so the revive run beats it quickly.
      if (_scene == 'Revive') 'highScore_rocketLaunch_medium': 10,
    });
    final storage = Storage(await SharedPreferences.getInstance());
    // Recent runs for the History preview on Profile.
    for (final (i, (g, best, _, time)) in _bests.reversed.indexed) {
      await storage.addHistory(
        RunRecord(
          game: GameId.values.byName(g),
          difficulty: Difficulty.medium,
          score: best - (i.isEven ? 0 : 40),
          duration: Duration(milliseconds: time ?? 70000 + i * 9000),
          playedAt: _today.subtract(Duration(hours: i * 3 + 1)),
          isBest: i.isEven,
        ),
      );
    }
    final leaderboard = Leaderboard(
      storage,
      api: FakeLeaderboardApi(rows: _ranks, rank: 2)..sprintTopPercent = 5,
    );

    await tester.pumpWidget(
      LogicSprintApp(
        appState: AppState(storage),
        leaderboard: leaderboard,
        ads: Ads(),
        version: '1.1',
      ),
    );
    await Future.delayed(const Duration(seconds: 4));
    await tester.pump();

    Future<void> startGame(String title, {String? level}) async {
      await tester.tap(find.text(title.toUpperCase()).first);
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
      final pick = find.text(level ?? 'MEDIUM');
      if (pick.evaluate().isNotEmpty) {
        await tester.tap(pick.first);
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 600));
      }
      await tester.tap(find.textContaining('START').last);
      await tester.pump();
    }

    switch (_scene) {
      case '':
        await _hold('home', 8000);
        await tester.tap(find.text('RANKS').last);
        await tester.pump();
        await _hold('ranks', 12000);
        await tester.tap(find.text('PROFILE').last);
        await tester.pump();
        await _hold('profile', 12000);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump();
        await _hold('profile_scrolled', 10000);
        // Rocket Launch in the first theme (under 1250 points): white hull,
        // blue trim, teal flame on black space, the app's own colours.
        await tester.tap(find.text('PLAY').last);
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2));
        await startGame('Rocket Launch');
        await _hold('rocket', 12000);
      case 'Line Split':
        await startGame('Line Split');
        await Future.delayed(const Duration(milliseconds: 2500));
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        final touch = _Touch(Offset(size.width * 0.23, size.height * 0.6));
        await Future.delayed(const Duration(milliseconds: 250));
        touch.moveTo(Offset(size.width * 0.235, size.height * 0.6));
        await Future.delayed(const Duration(milliseconds: 250));
        touch.up();
        await _hold('miss', 8000);
      case 'Revive':
        await startGame('Rocket Launch');
        await _hold('revive', 25000);
      case 'Angle Sense':
        await startGame('Angle Sense', level: 'MEDIUM');
        await _hold('scene', 10000);
      default:
        await startGame(_scene);
        await _hold('scene', 10000);
    }
    debugPrint('SHOT_MARK done');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    binding.shouldPropagateDevicePointerEvents = false;
  }, timeout: const Timeout(Duration(minutes: 5)));
}
