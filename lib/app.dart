import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'models/game_model.dart';
import 'models/score_model.dart';
import 'screens/about/about_screen.dart';
import 'screens/about/privacy_policy_screen.dart';
import 'screens/difficulty/difficulty_screen.dart';
import 'screens/game_select/game_select_screen.dart';
import 'screens/games/rocket_launch/rocket_launch_screen.dart';
import 'screens/games/memory_lane/memory_lane_screen.dart';
import 'screens/high_scores/high_scores_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/result/result_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/app_state.dart';
import 'services/leaderboard_service.dart';
import 'services/local_storage_service.dart';
import 'services/sound_service.dart';

class LogicSprintApp extends StatelessWidget {
  const LogicSprintApp({
    super.key,
    required this.appState,
    required this.storage,
    required this.soundService,
    required this.leaderboardService,
    required this.adService,
  });

  final AppState appState;
  final LocalStorageService storage;
  final SoundService soundService;
  final LeaderboardService leaderboardService;
  final AdService adService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<LocalStorageService>.value(value: storage),
        Provider<SoundService>.value(value: soundService),
        Provider<LeaderboardService>.value(value: leaderboardService),
        Provider<AdService>.value(value: adService),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppStrings.appTitle,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case AppRoutes.gameSelect:
        return MaterialPageRoute<void>(
          builder: (_) => const GameSelectScreen(),
          settings: settings,
        );
      case AppRoutes.difficulty:
        final gameType = settings.arguments as GameType;
        return MaterialPageRoute<void>(
          builder: (_) => DifficultyScreen(gameType: gameType),
          settings: settings,
        );
      case AppRoutes.rocketLaunch:
        final difficulty = settings.arguments as DifficultyLevel;
        return MaterialPageRoute<void>(
          builder: (_) => RocketLaunchScreen(difficulty: difficulty),
          settings: settings,
        );
      case AppRoutes.memoryLane:
        final difficulty = settings.arguments as DifficultyLevel;
        return MaterialPageRoute<void>(
          builder: (_) => MemoryLaneScreen(difficulty: difficulty),
          settings: settings,
        );
      case AppRoutes.result:
        final result = settings.arguments as ScoreModel;
        return MaterialPageRoute<void>(
          builder: (_) => ResultScreen(result: result),
          settings: settings,
        );
      case AppRoutes.highScores:
        return MaterialPageRoute<void>(
          builder: (_) => const HighScoresScreen(),
          settings: settings,
        );
      case AppRoutes.leaderboard:
        return MaterialPageRoute<void>(
          builder: (_) => const LeaderboardScreen(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRoutes.about:
        return MaterialPageRoute<void>(
          builder: (_) => const AboutScreen(),
          settings: settings,
        );
      case AppRoutes.privacyPolicy:
        return MaterialPageRoute<void>(
          builder: (_) => const PrivacyPolicyScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
    }
  }
}
