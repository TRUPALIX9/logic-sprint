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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store shots', (tester) async {
    SharedPreferences.setMockInitialValues(_prefs);
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

    // --dart-define=SCENE=<name> runs one game scene only.
    const scene = String.fromEnvironment('SCENE');
    if (scene.isNotEmpty) {
      await tester.tap(find.text(scene.toUpperCase()).first);
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
      await tester.tap(find.textContaining('START').last);
      await tester.pump();
      await _hold('scene', 12000);
      debugPrint('SHOT_MARK done');
      return;
    }

    await tester.tap(find.text('RANKS').last);
    await tester.pump();
    await _hold('ranks', 20000);

    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    await _hold('profile', 20000);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump();
    await _hold('profile_scrolled', 15000);

    // Rocket Launch in the first theme (under 1250 points): white hull, blue
    // trim, teal flame on black space, the app's own colours.
    await tester.tap(find.text('PLAY').last);
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.tap(find.text('ROCKET LAUNCH').first);
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.tap(find.textContaining('START').last);
    await tester.pump();
    await _hold('rocket', 12000);
    debugPrint('SHOT_MARK done');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
