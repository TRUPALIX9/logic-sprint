import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'services/ads.dart';
import 'services/leaderboard.dart';
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
  await Leaderboard.initSupabase();
  final ads = Ads();

  runApp(
    LogicSprintApp(
      appState: AppState(storage),
      leaderboard: Leaderboard(storage, appVersion: info.version),
      ads: ads,
      version: '${info.version} (${info.buildNumber})',
    ),
  );

  // After runApp so the consent form (if any) never blocks the first frame.
  unawaited(ads.initialize());
}
