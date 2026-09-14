import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'services/ads.dart';
import 'services/leaderboard.dart';
import 'services/leaderboard_api.dart';
import 'services/network.dart';
import 'services/storage.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = await Storage.open();
  final info = await PackageInfo.fromPlatform();
  await SupabaseLeaderboardApi.initialize();
  final leaderboard = Leaderboard(storage, api: SupabaseLeaderboardApi());
  final ads = Ads();
  final appState = AppState(storage);
  final network = Network();
  await network.start();

  runApp(
    LogicSprintApp(
      appState: appState,
      network: network,
      leaderboard: leaderboard,
      ads: ads,
      version: '${info.version} (${info.buildNumber})',
    ),
  );

  // After runApp: neither the consent form nor syncing runs finished offline
  // may block the first frame.
  unawaited(ads.initialize());
  unawaited(leaderboard.syncPending());
}
