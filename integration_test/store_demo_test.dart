// Plays the whole app on a simulator or device, end to end, for the store
// videos (App Store previews, the Play promo, App Review recordings):
// launch, all four games played for real with one revive, Result, Ranks and
// Profile. Ads stay off (Ads.initialize never runs) and the leaderboard is
// the in-memory fake, so nothing reaches AdMob or Supabase.
//
// Record it with tool/record_demo.sh, which prints DEMO_MARK lines (epoch ms)
// at the start of every scene so the clips can be cut without guessing.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/games/guess_color/guess_color_engine.dart';
import 'package:logic_sprint/games/memory_lane/memory_lane_engine.dart';
import 'package:logic_sprint/games/quick_math/quick_math_engine.dart';
import 'package:logic_sprint/games/rocket_launch/rocket_launch_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fake_leaderboard_api.dart';

/// A returning player with modest bests, so the demo runs beat them.
const _prefs = <String, Object>{
  'highScore_rocketLaunch_medium': 120,
  'highScore_memoryLane_medium': 150,
  'highScore_quickMath_medium': 140,
  'highScore_guessColor_medium': 140,
  'bestTime_memoryLane_medium': 61000,
  'bestTime_quickMath_medium': 44000,
  'plays_rocketLaunch_medium': 41,
  'plays_memoryLane_medium': 9,
  'plays_quickMath_medium': 37,
  'plays_guessColor_medium': 15,
  'playerName': 'NEON_FOX',
  'playerTag': 420,
  'rocketShip': 'rocket',
  'hearts': 3,
};

/// A Top 10 per game; NEON_FOX#0420 ("me") sits at #5 on each.
final _ranks = [
  for (final (game, scale) in const [
    ('rocketLaunch', 6.0),
    ('memoryLane', 1.4),
    ('quickMath', 1.0),
    ('guessColor', 0.9),
  ])
    for (final (i, (name, score, seconds)) in const [
      ('AXON#1187', 610, 131),
      ('SYNAPSE_9#3918', 560, 118),
      ('KIRA-X#0649', 520, 122),
      ('BITWISE#5380', 490, 97),
      ('NEON_FOX#0420', 420, 84),
      ('LUMEN#2203', 390, 88),
      ('DENDRITE#9075', 360, 79),
      ('AXON#7741', 330, 90),
      ('PIXEL_OWL#4466', 310, 71),
      ('QUARK#0812', 290, 76),
    ].indexed)
      {
        'player_id': name == 'NEON_FOX#0420' ? 'me' : 'p$i',
        'player_name': name,
        'score': (score * scale).round() ~/ 10 * 10,
        'game_type': game,
        'difficulty': 'medium',
        'duration_ms': seconds * 1000,
        'best_at': '2026-10-01T10:00:00.000Z',
      },
];

final _random = Random(7);

Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

/// A human-ish think time between [lo] and [hi] ms.
Future<void> _think(int lo, int hi) => _wait(lo + _random.nextInt(hi - lo));

void _mark(String scene) =>
    debugPrint('DEMO_MARK $scene ${DateTime.now().millisecondsSinceEpoch}');

Finder _type(String name, [bool Function(dynamic w)? where]) =>
    find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == name && (where?.call(w) ?? true),
    );

/// The engine behind the game body widget [body] (each holds `engine`).
T _engine<T>(WidgetTester tester, String body) =>
    (tester.widget(_type(body).first) as dynamic).engine as T;

/// A finger on the screen. Its events go in as device input, like a real
/// touch: the test binding draws a crosshair over test-dispatched pointers,
/// which must not show up in store videos.
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.pump();
  if (finder.evaluate().isEmpty) {
    return;
  }
  final touch = _Touch(tester.getCenter(finder.first));
  await _wait(70);
  touch.up();
}

/// Waits (up to [timeout]) until [finder] is on screen.
Future<bool> _until(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
    await _wait(50);
  }
  return false;
}

Future<void> _waitFor(bool Function() test, {int timeoutMs = 8000}) async {
  for (var t = 0; t < timeoutMs && !test(); t += 30) {
    await _wait(30);
  }
}

/// Opens [card]'s sheet on the Play tab, picks [difficulty] and starts.
Future<void> _start(
  WidgetTester tester,
  String card, {
  String? difficulty,
}) async {
  await _until(tester, find.text(card));
  await _tap(tester, find.text(card).last);
  await _until(tester, find.text('START'));
  await _wait(1200);
  if (difficulty != null) {
    await _tap(tester, find.text(difficulty));
    await _wait(700);
  }
  // A slow device can swallow the tap mid-animation: retry until the run
  // screen (it has a pause button and no START) is up.
  for (var i = 0; i < 4 && find.text('START').evaluate().isNotEmpty; i++) {
    await _tap(tester, find.text('START'));
    await _wait(900);
    await tester.pump();
  }
}

/// After a mistake: revive with a heart if [revive], else end the run; then
/// let Result show and go Home.
Future<void> _down(WidgetTester tester, {required bool revive}) async {
  await _wait(1300);
  if (revive && await _until(tester, find.textContaining('USE ❤'))) {
    await _tap(tester, find.textContaining('USE ❤'));
    return;
  }
  if (await _until(tester, find.text('END RUN'))) {
    await _think(600, 900);
    await _tap(tester, find.text('END RUN'));
  }
}

Future<void> _resultThenHome(WidgetTester tester) async {
  await _until(tester, find.text('HOME'));
  await _wait(3200);
  await _tap(tester, find.text('HOME'));
  await _wait(1500);
}

/// Picks the safest lane for the rocket: away from rocks about to cross its
/// band, without steering through one on the way, and not too far.
double _safest(RocketLaunchEngine e, double current) {
  double cost(double x) {
    var c = (x - e.rocketX).abs() * 0.4;
    final lo = min(x, e.rocketX), hi = max(x, e.rocketX);
    final travel = (x - e.rocketX).abs() / RocketLaunchEngine.steerSpeed;
    for (final rock in e.asteroids) {
      if (rock.y > RocketLaunchEngine.hitBottom) {
        continue;
      }
      final t = max(0.0, (RocketLaunchEngine.hitTop - rock.y) / rock.speed);
      if (t > 1.8) {
        continue;
      }
      final danger = 1 / (t + 0.2);
      if ((rock.x - x).abs() < 0.18) {
        c += 10 * danger;
      }
      if (t < travel && rock.x > lo - 0.13 && rock.x < hi + 0.13) {
        c += 5 * danger;
      }
    }
    return c;
  }

  var best = current;
  var bestCost = cost(current) - 0.5; // stay put unless clearly better
  for (var i = 0; i <= 18; i++) {
    final x = RocketLaunchEngine.minX + i * 0.05;
    final c = cost(x);
    if (c < bestCost) {
      best = x;
      bestCost = c;
    }
  }
  return best;
}

/// Flies for [seconds] (or until the run goes down). With [crash], aims at
/// the next rock instead, so the run goes down on purpose.
Future<void> _fly(
  WidgetTester tester,
  _Touch finger,
  Rect field,
  double seconds, {
  bool crash = false,
}) async {
  final engine = _engine<RocketLaunchEngine>(tester, '_RocketLaunchBody');
  var target = engine.rocketX;
  final end = DateTime.now().add(
    Duration(milliseconds: (seconds * 1000).round()),
  );
  while (DateTime.now().isBefore(end) && engine.state != RunState.down) {
    if (crash) {
      final incoming = engine.asteroids.where((r) => r.y < 0.7).toList()
        ..sort((a, b) => b.y.compareTo(a.y));
      if (incoming.isNotEmpty) {
        target = incoming.first.x;
      }
    } else {
      target = _safest(engine, target);
    }
    finger.moveTo(
      Offset(field.left + target * field.width, field.top + field.height * 0.8),
    );
    await _wait(16);
  }
}

Future<void> _rocketLaunch(WidgetTester tester) async {
  _mark('rocket_sheet');
  await _start(tester, 'ROCKET LAUNCH');
  _mark('rocket_play');
  final field = tester.getRect(_type('_RocketLaunchBody'));
  final finger = _Touch(
    Offset(field.center.dx, field.top + field.height * 0.8),
  );
  await _fly(tester, finger, field, 24);
  _mark('rocket_crash');
  await _fly(tester, finger, field, 15, crash: true);
  finger.up();
  _mark('rocket_revive');
  await _down(tester, revive: true);
  await _wait(300);
  final again = _Touch(Offset(field.center.dx, field.top + field.height * 0.8));
  await _fly(tester, again, field, 8);
  await _fly(tester, again, field, 15, crash: true);
  again.up();
  _mark('rocket_end');
  await _down(tester, revive: false);
  _mark('rocket_result');
  await _resultThenHome(tester);
}

Future<void> _memoryLane(WidgetTester tester) async {
  _mark('memory_sheet');
  await _start(tester, 'MEMORY LANE', difficulty: 'MEDIUM');
  _mark('memory_play');
  final engine = _engine<MemoryLaneEngine>(tester, '_MemoryLaneBody');
  for (var level = 1; level <= 4 && engine.isPlaying; level++) {
    await _waitFor(() => engine.canTap);
    await _think(350, 550);
    for (final tile in engine.sequence) {
      await _tap(tester, _type('_Tile', (w) => w.index == tile));
      await _think(260, 420);
    }
  }
  // One wrong tile ends the run.
  await _waitFor(() => engine.canTap);
  await _think(500, 700);
  final wrong = (engine.sequence.first + 1) % engine.tileCount;
  await _tap(tester, _type('_Tile', (w) => w.index == wrong));
  _mark('memory_end');
  await _down(tester, revive: false);
  _mark('memory_result');
  await _resultThenHome(tester);
}

Future<void> _quickMath(WidgetTester tester) async {
  _mark('math_sheet');
  await _start(tester, 'QUICK MATH', difficulty: 'MEDIUM');
  _mark('math_play');
  final engine = _engine<QuickMathEngine>(tester, '_QuickMathBody');
  for (var i = 0; i < 16 && engine.isPlaying; i++) {
    await _waitFor(() => !engine.locked);
    await _think(650, 1100);
    final answer = engine.problem.answer;
    await _tap(tester, _type('_AnswerButton', (w) => w.value == answer));
  }
  await _waitFor(() => !engine.locked);
  await _think(800, 1000);
  final wrong = engine.problem.options.firstWhere(
    (o) => o != engine.problem.answer,
  );
  await _tap(tester, _type('_AnswerButton', (w) => w.value == wrong));
  _mark('math_end');
  await _down(tester, revive: false);
  _mark('math_result');
  await _resultThenHome(tester);
}

Future<void> _guessColor(WidgetTester tester) async {
  _mark('color_sheet');
  await _start(tester, 'GUESS COLOR');
  _mark('color_play');
  final engine = _engine<GuessColorEngine>(tester, 'GuessColorBoard');
  // Through the shuffle, the countdown and into the COLOR | TEXT swaps.
  for (var i = 0; i < 27 && engine.isPlaying; i++) {
    await _waitFor(() => !engine.locked);
    await _think(engine.rule == GuessRule.text ? 750 : 550, 950);
    final target = engine.item.target;
    final slot = engine.item.buttons.indexWhere((b) => b.fill == target);
    await _tap(tester, _type('_AnswerButton', (w) => w.slot == slot));
  }
  await _waitFor(() => !engine.locked);
  await _think(700, 900);
  final target = engine.item.target;
  final wrong = engine.item.buttons.indexWhere((b) => b.fill != target);
  await _tap(tester, _type('_AnswerButton', (w) => w.slot == wrong));
  _mark('color_end');
  await _down(tester, revive: false);
  _mark('color_result');
  await _resultThenHome(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store demo', (tester) async {
    // Device input reaches the app (see _Touch); reset after the test.
    binding.shouldPropagateDevicePointerEvents = true;
    SharedPreferences.setMockInitialValues(_prefs);
    final storage = Storage(await SharedPreferences.getInstance());
    final leaderboard = Leaderboard(
      storage,
      api: FakeLeaderboardApi(rows: _ranks, rank: 5),
    );

    // A blank lead-in so the recording starts on black, not the old frame.
    await tester.pumpWidget(const ColoredBox(color: Colors.black));
    await _wait(1500);

    _mark('launch');
    await tester.pumpWidget(
      LogicSprintApp(
        appState: AppState(storage),
        leaderboard: leaderboard,
        ads: Ads(),
        version: '1.0.2 (7)',
      ),
    );
    await _wait(3500);

    await _rocketLaunch(tester);
    await _memoryLane(tester);
    await _quickMath(tester);
    await _guessColor(tester);

    _mark('ranks');
    await _tap(tester, find.text('RANKS').last);
    await _wait(5000);
    _mark('profile');
    await _tap(tester, find.text('PROFILE').last);
    await _wait(4000);
    _mark('done');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    // The binding checks this is back to false once the body returns.
    binding.shouldPropagateDevicePointerEvents = false;
  }, timeout: const Timeout(Duration(minutes: 10)));
}
