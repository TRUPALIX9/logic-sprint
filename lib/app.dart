import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'services/ads.dart';
import 'services/leaderboard.dart';
import 'state/app_state.dart';

/// Build info shown in Settings.
class AppInfo {
  const AppInfo(this.version);
  final String version;
}

/// Selected bottom-nav tab, so screens above the shell (Result) can switch it.
class NavTabs extends ValueNotifier<int> {
  NavTabs() : super(play);

  // Bottom-nav order, left to right.
  static const ranks = 0;
  static const play = 1;
  static const profile = 2;
}

class LogicSprintApp extends StatelessWidget {
  const LogicSprintApp({
    super.key,
    required this.appState,
    required this.leaderboard,
    required this.ads,
    required this.version,
    this.home,
  });

  final AppState appState;
  final Leaderboard leaderboard;
  final Ads ads;
  final String version;

  /// Overrides the splash screen (tests).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider(create: (_) => NavTabs()),
        ChangeNotifierProvider.value(value: leaderboard),
        Provider.value(value: ads),
        Provider.value(value: AppInfo(version)),
      ],
      child: MaterialApp(
        title: 'LogicSprint',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: home ?? const SplashScreen(),
      ),
    );
  }
}
