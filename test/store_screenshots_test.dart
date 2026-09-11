// Renders store / portfolio screenshots of the real screens at 1080×2400.
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
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/round_result.dart';
import 'package:logic_sprint/screens/result_screen.dart';
import 'package:logic_sprint/screens/shell.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _skip = !Platform.environment.containsKey('SCREENSHOTS');
const _out = 'assets/brand/store/screenshots';
const _pixelRatio = 2.625;
final _boundary = GlobalKey();

/// A returning player: a few bests, Quick Math last played, a display name.
const _prefs = <String, Object>{
  'highScore_rocketLaunch_medium': 120,
  'highScore_memoryLane_easy': 180,
  'highScore_memoryLane_medium': 150,
  'highScore_quickMath_easy': 260,
  'highScore_quickMath_medium': 420,
  'highScore_guessColor_medium': 140,
  'lastGame': 'quickMath',
  'lastDifficulty': 'medium',
  'playerName': 'NEON_FOX',
};

/// Sample leaderboard rows (Quick Math · Medium) for the Ranks shot.
final _ranks = [
  for (final (i, (name, score)) in const [
    ('AXON', 610),
    ('SYNAPSE_9', 560),
    ('KIRA-X', 520),
    ('BITWISE', 490),
    ('NEON_FOX', 420),
    ('LUMEN', 390),
    ('DENDRITE', 360),
    ('VOLT_RAY', 330),
  ].indexed)
    {
      'id': '$i',
      'player_name': name,
      'score': score,
      'game_type': 'quickMath',
      'difficulty': 'medium',
      'created_at': '2026-09-11T10:00:00.000Z',
    },
];

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
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = _pixelRatio
    ..padding = const FakeViewPadding(top: 63, bottom: 42)
    ..viewPadding = const FakeViewPadding(top: 63, bottom: 42);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(_prefs);
  final storage = Storage(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: LogicSprintApp(
        appState: AppState(storage),
        leaderboard: Leaderboard(
          storage,
          appVersion: '1.0.0',
          fetchTop: (_, _) async => _ranks,
          insert: (_) async {},
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
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
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

void main() {
  setUpAll(_loadFonts);

  testWidgets('01 home', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await _capture(tester, '01_home');
  });

  testWidgets('02 game sheet', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('MEMORY LANE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MEDIUM'));
    await tester.pumpAndSettle();
    await _capture(tester, '02_game_sheet');
  });

  testWidgets('03 rocket launch', skip: _skip, (tester) async {
    await _pumpApp(tester);
    await _startFromSheet(tester, 'ROCKET LAUNCH');
    await _frames(tester, const Duration(seconds: 3));
    // Asteroids are random: take a few shots and keep one without a hit flash.
    for (var take = 1; take <= 4; take++) {
      await _frames(tester, const Duration(milliseconds: 700));
      await _capture(tester, '03_rocket_launch_take$take');
    }
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
          score: 480,
          correct: 44,
          wrong: 3,
          previousBest: 420,
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
