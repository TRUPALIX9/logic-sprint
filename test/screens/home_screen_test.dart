import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/constants/app_routes.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/models/home_game_card_theme.dart';
import 'package:logic_sprint/widgets/ui/home_game_card.dart';
import 'package:logic_sprint/repositories/score_repository.dart';
import 'package:logic_sprint/services/firebase_leaderboard_service.dart';
import 'package:logic_sprint/screens/games/launch_rocket/launch_rocket_screen.dart';
import 'package:logic_sprint/screens/home/home_screen.dart';
import 'package:logic_sprint/screens/settings/settings_screen.dart';
import 'package:logic_sprint/services/app_state.dart';
import 'package:logic_sprint/widgets/app_gradient_background.dart';
import 'package:logic_sprint/services/leaderboard_service.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:logic_sprint/services/sound_service.dart';
import 'package:logic_sprint/config/admob_config.dart';
import 'package:logic_sprint/models/second_life_config.dart';
import 'package:logic_sprint/widgets/admob_banner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
    appState = await AppState.create(
      storage: storage,
      soundService: SoundService.silent(),
    );
  });

  Route<dynamic>? testOnGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.quickMath:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Quick Math')),
        );
      case AppRoutes.launchRocket:
        return MaterialPageRoute(builder: (_) => const LaunchRocketScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }

  Widget buildHome() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<LocalStorageService>.value(value: storage),
        Provider<SoundService>.value(value: SoundService.silent()),
        Provider<LeaderboardService>(
          create: (_) => LeaderboardService(
            storage: storage,
            firebaseLeaderboard: FirebaseLeaderboardService(
              storage: storage,
              scoreRepository: ScoreRepository(storage),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: testOnGenerateRoute,
        initialRoute: AppRoutes.home,
      ),
    );
  }

  testWidgets('home screen renders with gradient background', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppGradientBackground), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Scaffold && w.backgroundColor == Colors.transparent,
      ),
      findsOneWidget,
    );
  });

  testWidgets('header shows logo, LogicSprint, Brain Games, settings', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    expect(find.text('LogicSprint'), findsOneWidget);
    expect(find.text('Brain Games'), findsOneWidget);
    expect(find.text('Train math, memory, and logic'), findsNothing);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('mini games list matches wireframe', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    expect(find.text('Mini Games'), findsOneWidget);
    expect(find.text('Quick Math'), findsOneWidget);
    expect(find.text('Color Sequence'), findsOneWidget);
    expect(find.text('Emoji Match'), findsOneWidget);
    expect(find.text('Pattern Lock'), findsOneWidget);
    expect(find.text('Launch Rocket'), findsOneWidget);

    expect(find.text('Start Playing'), findsNothing);
    expect(find.text("Today's Challenge"), findsNothing);
    expect(find.text('True or False'), findsNothing);
    expect(find.text('30 Sec'), findsNothing);
    expect(find.text('Top 100'), findsNothing);
    expect(find.text('Games'), findsNothing);
    expect(find.text('Scores'), findsNothing);
  });

  testWidgets('home includes AdMob banner widget', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    expect(find.byType(AdMobBanner), findsOneWidget);
  });

  testWidgets('AdMobBanner uses test unit in debug', (tester) async {
    expect(
      AdMobBanner.unitIdForBuildMode(isDebug: true),
      AdMobConfig.bannerTest,
    );
    expect(
      AdMobBanner.unitIdForBuildMode(isDebug: false),
      AdMobConfig.bannerProduction,
    );
  });

  testWidgets('home screen does not show rewarded second life button', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    expect(find.text(SecondLifeConfig.watchAdButtonLabel), findsNothing);
  });

  testWidgets('quick math card opens game directly', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    final homeContext = tester.element(find.byType(HomeScreen));
    Navigator.of(homeContext).pushNamed(AppRoutes.quickMath);
    await tester.pump();
    expect(find.text('Quick Math'), findsWidgets);
  });

  testWidgets('launch rocket route opens game screen', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    final homeContext = tester.element(find.byType(HomeScreen));
    Navigator.of(homeContext).pushNamed(AppRoutes.launchRocket);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LaunchRocketScreen), findsOneWidget);
  });

  testWidgets('each home card uses a unique theme gradient', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    final gradients = <List<Color>>[];
    for (final game in homeLauncherGames) {
      gradients.add(HomeGameCardTheme.forGame(game.type).gradient);
    }
    expect(gradients.toSet().length, homeLauncherGames.length);
    expect(find.byType(HomeGameCard), findsNWidgets(homeLauncherGames.length));
    expect(find.textContaining('Highest Level:'), findsWidgets);
  });

  testWidgets('settings opens from gear icon', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Choose your difficulty'), findsNothing);
  });
}
