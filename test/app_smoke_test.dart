import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/app.dart';
import 'package:logic_sprint/screens/shell.dart';
import 'package:logic_sprint/services/ads.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final storage = Storage(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    LogicSprintApp(
      appState: AppState(storage),
      leaderboard: Leaderboard(
        storage,
        appVersion: 'test',
        fetchTop: (_, _) async => [],
        insert: (_) async {},
      ),
      ads: Ads(),
      version: '1.0.0 (1)',
      home: const Shell(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Loads the bundled fonts so layout (and overflow checks) match a device;
/// the default test font is much wider.
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

  testWidgets('home lists the four games and opens a game sheet', (
    tester,
  ) async {
    await _pumpApp(tester);
    for (final title in [
      'ROCKET LAUNCH',
      'MEMORY LANE',
      'QUICK MATH',
      'GUESS COLOR',
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('MEMORY LANE'));
    await tester.pumpAndSettle();
    expect(find.text('4×4 GRID'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('a Quick Math round ends on the Result screen', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('QUICK MATH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(find.text('= ?'), findsOneWidget);

    // Runs are endless: tap the bottom-left answer until one is wrong. No
    // rewarded ad is loaded in tests, so the run ends straight away.
    for (var i = 0; i < 40 && find.text('GAME OVER').evaluate().isEmpty; i++) {
      await tester.tapAt(const Offset(100, 740));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('POST TO GLOBAL TOP 10'), findsOneWidget);

    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.text('JUMP BACK IN'), findsOneWidget);
  });

  testWidgets('bottom nav switches between Play, Ranks and Stats', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR BESTS'), findsOneWidget);

    await tester.tap(find.text('RANKS'));
    await tester.pumpAndSettle();
    expect(find.text('GLOBAL TOP 10'), findsOneWidget);
    expect(find.textContaining('No scores yet'), findsOneWidget);
  });
}
