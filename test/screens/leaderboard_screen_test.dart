import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/screens/leaderboard/leaderboard_screen.dart';
import 'package:logic_sprint/services/leaderboard_cache_service.dart';
import 'package:logic_sprint/services/leaderboard_service.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('leaderboard filters stack on narrow width without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final cache = LeaderboardCacheService(storage);
    final service = LeaderboardService(storage: storage, cache: cache);

    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [Provider<LeaderboardService>.value(value: service)],
          child: const LeaderboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('All Games'), findsOneWidget);
    expect(find.text('Number Sequence'), findsNothing);

    await tester.tap(
      find.byType(DropdownButtonFormField<LeaderboardGameFilter>),
    );
    await tester.pumpAndSettle();

    expect(find.text('Color Sequence'), findsOneWidget);
  });
}
