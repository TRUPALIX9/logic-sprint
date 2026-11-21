import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/core/config.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/profile_stats.dart';
import 'package:logic_sprint/models/run_record.dart';
import 'package:logic_sprint/screens/profile/share_card.dart';
import 'package:logic_sprint/screens/history_screen.dart';
import 'package:logic_sprint/screens/profile/history_row.dart';
import 'package:logic_sprint/screens/profile_tab.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/network.dart';
import 'package:logic_sprint/ui/sprint_gauge.dart';
import 'package:logic_sprint/services/stats_share.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_leaderboard_api.dart';

/// Loads the bundled fonts so layout and overflow checks match a device.
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

/// A player with bests in four games (one of them new, Angle Sense), a rank
/// on one board, and five runs in History.
Future<Storage> _seeded({bool named = true}) async {
  SharedPreferences.setMockInitialValues({
    if (named) 'playerName': 'NEON_FOX',
    if (named) 'playerTag': 420,
    // Cached board: #4 on Quick Math · Medium.
    'leaderboardBoards': jsonEncode({
      'quickMath_medium': {
        'at': DateTime(2026, 11, 20).millisecondsSinceEpoch,
        'rank': 4,
        'rows': <Object>[],
      },
    }),
  });
  final storage = Storage(await SharedPreferences.getInstance());
  Future<void> run(
    GameId game,
    Difficulty difficulty,
    int score,
    int seconds,
  ) async {
    final duration = Duration(seconds: seconds);
    await storage.addPlay(game, difficulty);
    await storage.saveBestIfHigher(
      game,
      difficulty,
      score,
      duration: game.tracksTime ? duration : null,
    );
    await storage.addHistory(
      RunRecord(
        game: game,
        difficulty: difficulty,
        score: score,
        duration: duration,
        playedAt: DateTime(2026, 11, 20, 9),
      ),
    );
  }

  await run(GameId.rocketLaunch, GameId.rampDifficulty, 5140, 120);
  await run(GameId.quickMath, Difficulty.easy, 200, 40);
  await run(GameId.quickMath, Difficulty.medium, 310, 70);
  await run(GameId.memoryLane, Difficulty.hard, 460, 63);
  await run(GameId.angleSense, Difficulty.hard, 212, 50);
  return storage;
}

Future<void> _pumpProfile(
  WidgetTester tester,
  Storage storage, {
  StatsSharer sharer = const StatsSharer(),
  Size size = const Size(1170, 2532),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState(storage)),
        ChangeNotifierProvider.value(value: NavTabs()),
        ChangeNotifierProvider.value(
          value: Leaderboard(storage, api: FakeLeaderboardApi()),
        ),
        Provider.value(value: Ads()),
        Provider.value(value: Network.fixed(true)),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: ProfileTab(sharer: sharer)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// All six games, every kind of line: ranked ramp game, difficulty games
/// with bests on one or more levels, and games not played yet.
ProfileStats _stats({bool named = true, int? sprintTop}) => ProfileStats(
  name: named ? 'NEON_FOX' : null,
  tag: named ? '0420' : null,
  runs: 120,
  played: const Duration(hours: 3, minutes: 12),
  playedIsPartial: false,
  sprintTop: sprintTop,
  games: const [
    GameStat(game: GameId.rocketLaunch, best: 5140, runs: 41, rank: 4),
    GameStat(
      game: GameId.memoryLane,
      best: 460,
      runs: 22,
      bests: {
        Difficulty.easy: 120,
        Difficulty.medium: 300,
        Difficulty.hard: 460,
      },
      difficulty: Difficulty.hard,
      bestTime: Duration(seconds: 63),
      rank: 9,
    ),
    GameStat(
      game: GameId.quickMath,
      best: 310,
      runs: 18,
      bests: {Difficulty.medium: 310},
      difficulty: Difficulty.medium,
      bestTime: Duration(seconds: 70),
    ),
    GameStat(game: GameId.guessColor, best: 0, runs: 0),
    GameStat(
      game: GameId.angleSense,
      best: 1212,
      runs: 9,
      bests: {Difficulty.hard: 1212},
      difficulty: Difficulty.hard,
      rank: 12,
    ),
    GameStat(game: GameId.lineSplit, best: 0, runs: 0),
  ],
);

/// Any play count: "1 run", "22 runs", a "Runs"/"Played" total, "Played 3".
/// ("Not played yet" is not a count.)
final _playCount = RegExp(
  r'\d+\s+runs?\b|^(runs|played)$|\bplayed\s+\d',
  caseSensitive: false,
);

/// The words "Sprint Score" are never shown.
final _sprintWords = RegExp('sprint score', caseSensitive: false);

void main() {
  setUpAll(_loadFonts);

  group('Profile tab', () {
    testWidgets('name, gauge, each game once, History, Share at the bottom', (
      tester,
    ) async {
      await _pumpProfile(tester, await _seeded());

      expect(tester.takeException(), isNull);
      // Name + dimmed code, and no wordmark on Profile.
      expect(find.text('NEON_FOX#0420', findRichText: true), findsOneWidget);
      expect(find.text('LOGICSPRINT', findRichText: true), findsNothing);

      // Sprint Score gauge: no score yet, so dim with no rank.
      expect(find.byType(SprintGauge), findsOneWidget);
      expect(find.text('PLAY MORE GAMES TO GET YOUR SCORE'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+%')), findsNothing);
      expect(find.textContaining(_sprintWords), findsNothing);

      // Each game's best once, in GameId order (the Home grid's order).
      expect(find.text('YOUR BESTS'), findsOneWidget);
      double top(GameId g) =>
          tester.getTopLeft(find.byKey(ValueKey('best-${g.name}'))).dy;
      for (final game in GameId.values) {
        expect(find.text(game.title.toUpperCase()), findsOneWidget);
        if (game.index > 0) {
          expect(top(game), greaterThan(top(GameId.values[game.index - 1])));
        }
      }
      final rocket = tester.widget<Text>(find.text('5,140'));
      expect(rocket.style?.color, GameId.rocketLaunch.accent);
      expect(find.text('5,140'), findsOneWidget, reason: 'no second grid');

      // Easy/Medium/Hard bests on one line; a ramp game shows its skill.
      expect(find.text('E 200 · M 310 · H —'), findsOneWidget);
      expect(find.text('E — · M — · H 460'), findsOneWidget);
      expect(find.text('E — · M — · H 212'), findsOneWidget);
      expect(find.text('Reflex'), findsOneWidget);
      expect(find.text('Not played yet'), findsNWidgets(2));

      // Play counts and totals are hidden for now.
      expect(find.textContaining(_playCount), findsNothing);

      // History: the last three runs and a way into the full page.
      expect(find.text('HISTORY'), findsOneWidget);
      expect(find.byType(HistoryRow), findsNWidgets(3));
      expect(
        tester.getTopLeft(find.text('YOUR BESTS')).dy,
        lessThan(tester.getTopLeft(find.text('HISTORY')).dy),
      );

      // One Share button, last on the page, with the note.
      await tester.scrollUntilVisible(find.text(linkCopiedNote), 200);
      expect(find.text('SHARE'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('HISTORY')).dy,
        lessThan(tester.getTopLeft(find.text('SHARE')).dy),
      );
      for (final row in find.byType(HistoryRow).evaluate()) {
        expect(
          tester.getBottomLeft(find.byWidget(row.widget)).dy,
          lessThan(tester.getTopLeft(find.text('SHARE')).dy),
        );
      }
      expect(find.textContaining(_playCount), findsNothing);
    });

    testWidgets('See all opens the History page', (tester) async {
      await _pumpProfile(tester, await _seeded());
      await tester.tap(find.text('SEE ALL'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('5 RUNS', findRichText: true), findsOneWidget);
      expect(find.byType(HistoryRow), findsNWidgets(5));
    });

    testWidgets('lays out at 320 pt wide without overflow', (tester) async {
      await _pumpProfile(tester, await _seeded(), size: const Size(960, 1704));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(linkCopiedNote), 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no name yet: prompt to set one', (tester) async {
      await _pumpProfile(tester, await _seeded(named: false));
      expect(find.text('SET NAME'), findsOneWidget);
      expect(find.text('Set a name to show on the boards'), findsOneWidget);
      expect(find.textContaining('NEON_FOX', findRichText: true), findsNothing);
    });

    testWidgets('Share copies the link and opens the system sheet once', (
      tester,
    ) async {
      final clipboard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      final sent = <ShareParams>[];
      final sharer = StatsSharer(
        render: (child, {required size, required pixelRatio}) async {
          expect(child, isA<ShareCard>());
          // Every game goes on the card, in GameId order.
          expect(
            (child as ShareCard).stats.games.map((g) => g.game),
            GameId.values,
          );
          expect(size * pixelRatio, const Size(1080, 1920));
          return Uint8List.fromList([1, 2, 3]);
        },
        share: (params) async => sent.add(params),
      );
      await _pumpProfile(tester, await _seeded(), sharer: sharer);

      // Share is at the bottom of the page: scroll to it.
      await tester.scrollUntilVisible(find.text('SHARE'), 200);
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();

      // Straight to the system sheet: no chooser of our own.
      expect(sent, hasLength(1));
      expect(sent.single.text, AppConfig.shareText);
      expect(sent.single.text, contains('https://'));
      expect(sent.single.files!.single.mimeType, 'image/png');
      expect(sent.single.sharePositionOrigin, isNotNull);
      expect(clipboard, [AppConfig.shareUrl]);
      expect(find.text('SHARE'), findsOneWidget, reason: 'button is back');
    });

    testWidgets('a failed share says so', (tester) async {
      final sharer = StatsSharer(
        render: (child, {required size, required pixelRatio}) async =>
            Uint8List.fromList([1]),
        share: (params) async => throw StateError('no sheet'),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      await _pumpProfile(tester, await _seeded(), sharer: sharer);
      // Share is at the bottom of the page: scroll to it.
      await tester.scrollUntilVisible(find.text('SHARE'), 200);
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't share right now. Try again."), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('ProfileStats', () {
    test('best across difficulties, its rank and time; partial played', () {
      final stats = ProfileStats.from(
        name: 'A',
        tag: '0001',
        best: (g, d) => switch ((g, d)) {
          (GameId.quickMath, Difficulty.easy) => 300,
          (GameId.quickMath, Difficulty.hard) => 300,
          _ => 0,
        },
        bestTime: (g, d) => d == Difficulty.hard
            ? const Duration(seconds: 50)
            : const Duration(seconds: 30),
        plays: (g, d) => g == GameId.quickMath ? 2 : 0,
        rank: (g, d) => d == Difficulty.hard ? 7 : null,
        history: const [],
      );
      final math = stats.games.firstWhere((g) => g.game == GameId.quickMath);
      expect(math.best, 300);
      expect(math.difficulty, Difficulty.hard, reason: 'tie → harder');
      expect(math.rank, 7);
      expect(math.bestTime, const Duration(seconds: 50));
      expect(math.bests, {
        Difficulty.easy: 300,
        Difficulty.medium: 0,
        Difficulty.hard: 300,
      });
      expect(math.runs, 6);
      expect(stats.runs, 6);
      expect(stats.playedIsPartial, isTrue);
      expect(stats.sprintTop, isNull);
      expect(stats.games.map((g) => g.game), GameId.values);
      final rocket = stats.games.first;
      expect(rocket.bests, isEmpty, reason: 'ramp game: one board');
    });

    test('formatPlayed and formatScore', () {
      expect(formatPlayed(const Duration(hours: 3, minutes: 12)), '3h 12m');
      expect(formatPlayed(const Duration(minutes: 12, seconds: 9)), '12m');
      expect(formatPlayed(const Duration(seconds: 45)), '45s');
      expect(formatPlayed(Duration.zero), '0m');
      expect(formatScore(5140), '5,140');
      expect(formatScore(1234567), '1,234,567');
      expect(formatScore(42), '42');
    });
  });

  group('Share image', () {
    Future<void> pumpCard(WidgetTester tester, ProfileStats stats) async {
      tester.view
        ..physicalSize = ShareCard.pixelSize
        ..devicePixelRatio = ShareCard.pixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Center(child: ShareCard(stats: stats)),
        ),
      );
    }

    void expectAllGames(WidgetTester tester) {
      double top(GameId g) =>
          tester.getTopLeft(find.text(g.title.toUpperCase())).dy;
      for (final game in GameId.values) {
        expect(find.text(game.title.toUpperCase()), findsOneWidget);
      }
      // Two per row in GameId order: 1·2 / 3·4 / 5·6.
      for (var i = 0; i + 1 < GameId.values.length; i += 2) {
        expect(top(GameId.values[i]), top(GameId.values[i + 1]));
        expect(
          tester.getTopLeft(find.text(GameId.values[i].title.toUpperCase())).dx,
          lessThan(
            tester
                .getTopLeft(find.text(GameId.values[i + 1].title.toUpperCase()))
                .dx,
          ),
        );
        if (i > 0) {
          expect(top(GameId.values[i]), greaterThan(top(GameId.values[i - 2])));
        }
      }
    }

    testWidgets('card holds all six games without overflow', (tester) async {
      await pumpCard(tester, _stats());
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ShareCard)), ShareCard.size);
      expect(find.text('LOGICSPRINT', findRichText: true), findsOneWidget);
      expect(find.text('NEON_FOX#0420', findRichText: true), findsOneWidget);
      // No Sprint Score yet → "My bests", no gauge.
      expect(find.text('MY BESTS'), findsOneWidget);
      expect(find.byType(SprintGauge), findsNothing);
      expectAllGames(tester);
      expect(find.text('5,140'), findsOneWidget);
      expect(find.text('1,212'), findsOneWidget);
      expect(find.text('Hard · #9 · 1:03'), findsOneWidget);
      expect(find.text('Hard · #12'), findsOneWidget);
      expect(find.text('Not played yet'), findsNWidgets(2));
      // No play counts, no "Sprint Score" words.
      expect(find.textContaining(_playCount), findsNothing);
      expect(find.textContaining(_sprintWords), findsNothing);
      expect(find.text('CAN YOU BEAT IT?'), findsOneWidget);
      expect(find.text(AppConfig.shareHost), findsOneWidget);
      // The footer stays inside the card.
      expect(
        tester.getBottomLeft(find.text(AppConfig.shareHost)).dy,
        lessThanOrEqualTo(tester.getBottomLeft(find.byType(ShareCard)).dy),
      );
    });

    testWidgets('with a Sprint Score it shows a small static gauge', (
      tester,
    ) async {
      await pumpCard(tester, _stats(sprintTop: 4));
      expect(tester.takeException(), isNull);
      final gauge = tester.widget<SprintGauge>(find.byType(SprintGauge));
      expect(gauge.animate, isFalse);
      expect(find.text('TOP 4%'), findsOneWidget);
      expect(find.text('MY BESTS'), findsNothing);
      expect(find.textContaining(_sprintWords), findsNothing);
      expectAllGames(tester);
    });

    testWidgets('no score yet: no gauge on the card', (tester) async {
      await pumpCard(tester, _stats());
      expect(tester.takeException(), isNull);
      expect(find.byType(SprintGauge), findsNothing);
      expect(find.text('MY BESTS'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('PLAY MORE'), findsNothing);
    });

    testWidgets('a long name with a score still fits', (tester) async {
      final stats = _stats(sprintTop: 20);
      await pumpCard(
        tester,
        ProfileStats(
          name: 'WWWWWWWWWWWWWWWW',
          tag: '9999',
          runs: stats.runs,
          played: stats.played,
          playedIsPartial: false,
          sprintTop: 20,
          games: stats.games,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('TOP 20%'), findsOneWidget);
      expectAllGames(tester);
    });

    testWidgets('renders off-screen to a 1080×1920 PNG', (tester) async {
      final png = await tester.runAsync(
        () => const StatsSharer().image(_stats()),
      );
      expect(png, isNotNull);
      // PNG signature, then IHDR width/height (big-endian).
      expect(png!.sublist(1, 4), utf8.encode('PNG'));
      final header = ByteData.sublistView(png, 16, 24);
      expect(header.getUint32(0), 1080);
      expect(header.getUint32(4), 1920);
      final out = Platform.environment['SHARE_PNG_DIR'];
      if (out != null) {
        File('$out/share_story.png').writeAsBytesSync(png);
      }
    });
  });
}
