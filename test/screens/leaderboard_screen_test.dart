import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/repositories/score_repository.dart';
import 'package:logic_sprint/screens/leaderboard/leaderboard_screen.dart';
import 'package:logic_sprint/services/firebase_leaderboard_service.dart';
import 'package:logic_sprint/services/leaderboard_service.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('all-time leaderboard shows game selector', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final repo = ScoreRepository(storage);
    final service = LeaderboardService(
      storage: storage,
      firebaseLeaderboard: FirebaseLeaderboardService(
        storage: storage,
        scoreRepository: repo,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(390, 800));
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
    expect(find.text('All-Time Leaderboard'), findsOneWidget);
    expect(find.text('Quick Math'), findsWidgets);
    expect(find.text('All Difficulties'), findsNothing);
  });
}
