import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import 'app.dart';
import 'repositories/score_repository.dart';
import 'services/app_state.dart';
import 'services/final_score_service.dart';
import 'services/firebase_leaderboard_service.dart';
import 'services/firebase_service.dart';
import 'services/leaderboard_service.dart';
import 'services/local_storage_service.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();
  await AppFirebaseService.initialize();

  final storage = await LocalStorageService.create();
  final soundService = SoundService();
  final scoreRepository = ScoreRepository(storage);
  final firebaseLeaderboard = FirebaseLeaderboardService(
    storage: storage,
    scoreRepository: scoreRepository,
  );
  final leaderboardService = LeaderboardService(
    storage: storage,
    firebaseLeaderboard: firebaseLeaderboard,
  );
  final finalScoreService = FinalScoreService(
    scoreRepository: scoreRepository,
    firebaseLeaderboard: firebaseLeaderboard,
    storage: storage,
  );

  await firebaseLeaderboard.syncPendingAllTimeSubmissions();

  final appState = await AppState.create(
    storage: storage,
    soundService: soundService,
  );

  runApp(
    LogicSprintApp(
      appState: appState,
      storage: storage,
      soundService: soundService,
      leaderboardService: leaderboardService,
      finalScoreService: finalScoreService,
    ),
  );
}
