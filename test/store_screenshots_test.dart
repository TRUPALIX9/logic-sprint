// Renders store / portfolio screenshots of the real screens.
// Skipped unless SCREENSHOTS is set; see README "Store screenshots".
@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/games/rocket_launch/rocket_launch_engine.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/round_result.dart';
import 'package:logic_sprint/models/run_record.dart';
import 'package:logic_sprint/screens/result_screen.dart';
import 'package:logic_sprint/screens/shell.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_leaderboard_api.dart';

final _skip = !Platform.environment.containsKey('SCREENSHOTS');

// SCREENSHOTS=play renders 1080×1920 (9:16, what Google Play accepts) into
// google_play/screenshots; SCREENSHOTS=appstore renders 1320×2868 (App Store
// 6.9" iPhone, 440×956 pt at 3×, Dynamic Island and home indicator insets)
// into app_store/screenshots; anything else renders 1080×2400 (portfolio).
final _mode = switch (Platform.environment['SCREENSHOTS']) {
  'play' => (
    'assets/brand/store/google_play/screenshots',
    const Size(1080, 1920),
    2.625,
    const FakeViewPadding(top: 63, bottom: 42),
  ),
  'appstore' => (
    'assets/brand/store/app_store/screenshots',
    const Size(1320, 2868),
    3.0,
    const FakeViewPadding(top: 186, bottom: 102),
  ),
  _ => (
    'assets/brand/store/screenshots',
    const Size(1080, 2400),
    2.625,
    const FakeViewPadding(top: 63, bottom: 42),
  ),
};
final _out = _mode.$1;
final _size = _mode.$2;
final _pixelRatio = _mode.$3;
final _padding = _mode.$4;
final _boundary = GlobalKey();

/// A returning player: bests, play counts, Quick Math last played, a name.
const _prefs = <String, Object>{
  'highScore_rocketLaunch_medium': 120,
  'highScore_memoryLane_easy': 180,
  'highScore_memoryLane_medium': 150,
  'highScore_quickMath_easy': 260,
  'highScore_quickMath_medium': 420,
  'highScore_guessColor_medium': 140,
  'bestTime_memoryLane_easy': 58000,
  'bestTime_memoryLane_medium': 61000,
  'bestTime_quickMath_easy': 65000,
  'bestTime_quickMath_medium': 84000,
  'plays_rocketLaunch_medium': 41,
  'plays_memoryLane_easy': 6,
  'plays_memoryLane_medium': 9,
  'plays_quickMath_easy': 12,
  'plays_quickMath_medium': 37,
  'plays_quickMath_hard': 4,
  'plays_guessColor_medium': 15,
  'lastGame': 'quickMath',
  'lastDifficulty': 'medium',
  'playerName': 'NEON_FOX',
  'playerTag': 420,
  'rocketShip': 'missile',
  'hearts': 2,
};

/// Sample Top 10 (Quick Math · Medium) for the Ranks shot. NEON_FOX#0420 is
/// the player ("me" in FakeLeaderboardApi); two players share AXON.
final _ranks = [
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
      'score': score,
      'game_type': 'quickMath',
      'difficulty': 'medium',
      'duration_ms': seconds * 1000,
      'best_at': '2026-09-11T10:00:00.000Z',
    },
];

/// Recent runs for Profile's History, oldest first.
List<RunRecord> _history() {
  final now = DateTime.now();
  RunRecord run(
    GameId game,
    Difficulty d,
    int score,
    int seconds,
    int hoursAgo, {
    bool best = false,
  }) => RunRecord(
    game: game,
    difficulty: d,
    score: score,
    duration: Duration(seconds: seconds),
    playedAt: now.subtract(Duration(hours: hoursAgo)),
    isBest: best,
  );
  return [
    run(GameId.memoryLane, Difficulty.easy, 180, 58, 72, best: true),
    run(GameId.guessColor, Difficulty.medium, 140, 95, 50, best: true),
    run(GameId.quickMath, Difficulty.medium, 380, 72, 26),
    run(GameId.rocketLaunch, Difficulty.medium, 120, 64, 5, best: true),
    run(GameId.quickMath, Difficulty.medium, 420, 84, 2, best: true),
  ];
}

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
  final icons = Platform.environment['ICONS_FONT'];
  if (icons != null && File(icons).existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(File(icons).readAsBytesSync())),
      );
    await loader.load();
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = _size
    ..devicePixelRatio = _pixelRatio
    ..padding = _padding
    ..viewPadding = _padding;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(_prefs);
  final storage = Storage(await SharedPreferences.getInstance());
  for (final run in _history()) {
    await storage.addHistory(run);
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: LogicSprintApp(
        appState: AppState(storage),
        leaderboard: Leaderboard(
          storage,
          api: FakeLeaderboardApi(rows: _ranks, rank: 5),
        ),
        ads: Ads(),
        version: '1.0.0 (1)',
        home: const Shell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Advances [duration] in 16 ms frames (games run tickers and timers, so
/// pumpAndSettle would never return).
Future<void> _frames(WidgetTester tester, Duration duration) async {
  for (
    var t = Duration.zero;
    t < duration;
    t += const Duration(milliseconds: 16)
  ) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_opaquePng(rgba!, image.width, image.height));
  });
}

/// Encodes [rgba] as a 24-bit PNG (no alpha channel, which both stores
/// prefer), flattened onto the app's black background.
List<int> _opaquePng(ByteData rgba, int width, int height) {
  final rows = Uint8List(height * (1 + width * 3));
  var o = 0;
  for (var y = 0; y < height; y++) {
    rows[o++] = 0; // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      // rawRgba is premultiplied, so dropping alpha composites onto black.
      for (var c = 0; c < 3; c++) {
        rows[o++] = rgba.getUint8(i + c);
      }
    }
  }
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    var crc = 0xFFFFFFFF;
    for (final b in body) {
      crc ^= b;
      for (var k = 0; k < 8; k++) {
        crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return [
      ...(ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
      ...body,
      ...(ByteData(4)..setUint32(0, crc ^ 0xFFFFFFFF)).buffer.asUint8List(),
    ];
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2); // colour type: RGB
  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    ...chunk('IHDR', header.buffer.asUint8List()),
    ...chunk('IDAT', ZLibCodec(level: 6).encode(rows)),
    ...chunk('IEND', const []),
  ];
}

/// Disposes the tree so round timers are cancelled before the test ends.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _startFromSheet(
  WidgetTester tester,
  String card, {
  String? difficulty,
}) async {
  await tester.tap(find.text(card).last);
  await tester.pumpAndSettle();
  if (difficulty != null) {
    await tester.tap(find.text(difficulty));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('START'));
  await _frames(tester, const Duration(milliseconds: 500));
}

const _frame = Duration(milliseconds: 16);

void main() {
  setUpAll(_loadFonts);

  testWidgets('01 home', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await _capture(tester, '01_home');
  });

  testWidgets('02 game sheet', skip: _skip, (tester) async {
    await _pumpApp(tester);
    // Rocket Launch's sheet: rules, best, and the ship picker.
    await tester.tap(find.text('ROCKET LAUNCH').last);
    await tester.pumpAndSettle();
    await _capture(tester, '02_game_sheet');
  });

  testWidgets('03 rocket launch', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await _startFromSheet(tester, 'ROCKET LAUNCH');
    final engine =
        (tester.widget(
                      find.byWidgetPredicate(
                        (w) => w.runtimeType.toString() == '_RocketLaunchBody',
                      ),
                    )
                    as dynamic)
                .engine
            as RocketLaunchEngine;
    // Past 3750 points: the purple Nebula theme, fully rolled in.
    engine.score = 3 * RocketLaunchEngine.themeEvery + 180;
    // Rocks never reach the ship, so no take ends in a crash.
    Future<void> fly(Duration duration) async {
      for (var t = Duration.zero; t < duration; t += _frame) {
        engine.asteroids.removeWhere((rock) => rock.y > 0.7);
        await tester.pump(_frame);
      }
    }

    await fly(const Duration(seconds: 4));
    // A finger held left of centre: the ship steers there and the
    // "Touch and drag" hint fades out.
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final finger = await tester.startGesture(
      Offset(size.width * 0.38, size.height * 0.8),
    );
    await fly(const Duration(seconds: 1));
    for (var take = 1; take <= 4; take++) {
      await fly(const Duration(milliseconds: 700));
      await _capture(tester, '03_rocket_launch_take$take');
    }
    await finger.up();
    await _teardown(tester);
  });

  testWidgets('04 memory lane', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await _startFromSheet(tester, 'MEMORY LANE', difficulty: 'MEDIUM');
    // Lead-in is 600 ms, then each tile flashes for 450 ms.
    await _frames(tester, const Duration(milliseconds: 1400));
    await _capture(tester, '04_memory_lane');
    await _teardown(tester);
  });

  testWidgets('05 quick math', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('JUMP BACK IN'));
    await _frames(tester, const Duration(milliseconds: 800));
    await _capture(tester, '05_quick_math');
    await _teardown(tester);
  });

  testWidgets('06 guess color', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await _startFromSheet(tester, 'GUESS COLOR');
    await _frames(tester, const Duration(milliseconds: 500));
    await _capture(tester, '06_guess_color');
    await _teardown(tester);
  });

  testWidgets('07 result', skip: _skip, (tester) async {
    await _pumpApp(tester);
    Navigator.of(tester.element(find.byType(Shell))).push(
      resultRoute(
        const RoundResult(
          game: GameId.quickMath,
          difficulty: Difficulty.medium,
          score: 420,
          correct: 38,
          duration: Duration(minutes: 1, seconds: 24),
          previousBest: 360,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, '07_result');
  });

  testWidgets('08 ranks', skip: _skip, (tester) async {
    await _pumpApp(tester);
    tester.element(find.byType(Shell)).read<NavTabs>().value = NavTabs.ranks;
    await tester.pumpAndSettle();
    await _capture(tester, '08_ranks');
  });

  testWidgets('09 profile', skip: _skip, (tester) async {
    await _pumpApp(tester);
    tester.element(find.byType(Shell)).read<NavTabs>().value = NavTabs.profile;
    await tester.pumpAndSettle();
    await _capture(tester, '09_profile');
  });
}
