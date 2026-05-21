import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/app_state.dart';
import 'services/local_storage_service.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await LocalStorageService.create();
  final soundService = SoundService();
  final appState = await AppState.create(
    storage: storage,
    soundService: soundService,
  );

  runApp(
    LogicSprintApp(
      appState: appState,
      storage: storage,
      soundService: soundService,
    ),
  );
}
