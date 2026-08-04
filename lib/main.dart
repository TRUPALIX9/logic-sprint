import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/ad_service.dart';
import 'services/app_state.dart';
import 'services/firebase_service.dart';
import 'services/leaderboard_cache_service.dart';
import 'services/leaderboard_service.dart';
import 'services/local_storage_service.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppFirebaseService.initialize();

  final storage = await LocalStorageService.create();
  final soundService = SoundService();
  final leaderboardService = LeaderboardService(
    storage: storage,
    cache: LeaderboardCacheService(storage),
  );
  final adService = AdService(storage: storage);
  await adService.initialize();

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
      adService: adService,
    ),
  );
}
