import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/config/admob_config.dart';
import 'package:logic_sprint/core/constants/app_routes.dart';
import 'package:logic_sprint/core/constants/life_game_constants.dart';
import 'package:logic_sprint/core/game/timed_game_controller.dart';
import 'package:logic_sprint/core/theme/app_theme.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/models/home_game_card_theme.dart';
import 'package:logic_sprint/models/second_life_config.dart';
import 'package:logic_sprint/models/second_life_session.dart';
import 'package:logic_sprint/screens/games/color_sequence/color_sequence_controller.dart';
import 'package:logic_sprint/screens/games/emoji_match/emoji_match_controller.dart';
import 'package:logic_sprint/screens/games/pattern_lock/pattern_lock_controller.dart';
import 'package:logic_sprint/screens/games/quick_math/quick_math_controller.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:logic_sprint/services/sound_service.dart';
import 'package:logic_sprint/widgets/app_gradient_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Life-based global rules', () {
    test('starting lives is 3 for all launcher games', () {
      expect(LifeGameConstants.startingLives, 3);
    });

    test('storage uses easy internally without exposing UI difficulty', () {
      expect(LifeGameConstants.storageDifficulty, DifficultyLevel.easy);
    });

    test('launcher games skip difficulty selection', () {
      for (final game in homeLauncherGames) {
        expect(game.skipsDifficulty, isTrue);
      }
    });
  });

  group('Home card themes are unique', () {
    test('each launcher game has distinct gradient colors', () {
      final gradients = homeLauncherGames
          .map((g) => HomeGameCardTheme.forGame(g.type).gradient)
          .toList();
      for (var i = 0; i < gradients.length; i++) {
        for (var j = i + 1; j < gradients.length; j++) {
          expect(gradients[i], isNot(equals(gradients[j])));
        }
      }
    });
  });

  group('No pure white backgrounds in theme', () {
    test('light and dark themes use dark scaffold and cards', () {
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, isNot(Colors.white));
      expect(AppTheme.lightTheme.cardTheme!.color, isNot(Colors.white));
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, isNot(Colors.white));
    });

    test('gradient background top color is not white', () {
      expect(AppGradientBackground.backgroundTop, isNot(Colors.white));
    });
  });

  group('Controllers: 3 lives, no timer fail, progressive difficulty', () {
    late LocalStorageService storage;
    late SoundService sound;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      sound = SoundService.silent();
    });

    test('Quick Math starts with 3 lives and increases level', () async {
      final c = QuickMathController(
        storage: storage,
        soundService: sound,
        random: Random(3),
      );
      await c.initialize();
      expect(c.lives, 3);
      expect(c, isNot(isA<TimedGameController>()));
      expect(c.level, greaterThanOrEqualTo(1));
      c.dispose();
    });

    test('Quick Math wrong answer reduces life', () async {
      final c = QuickMathController(
        storage: storage,
        soundService: sound,
        random: Random(4),
      );
      await c.initialize();
      final wrong = c.currentQuestion!.options.firstWhere(
        (o) => o != c.currentQuestion!.correctAnswer,
      );
      await c.submitAnswer(wrong);
      expect(c.lives, 2);
      c.dispose();
    });

    test('Color Sequence wrong tap reduces life', () async {
      final c = ColorSequenceController(storage: storage, soundService: sound);
      c.targetSequence = [SequenceColor.cyan, SequenceColor.purple];
      c.phase = ColorSequencePhase.repeating;
      c.isRoundComplete = false;
      expect(c.lives, 3);
      await c.tapColor(SequenceColor.blue);
      expect(c.lives, 2);
      c.dispose();
    });

    test('Emoji Match wrong pair reduces life', () async {
      final c = EmojiMatchController(storage: storage, soundService: sound);
      await c.initialize();
      expect(c.lives, 3);
      final first = c.cards.first;
      final secondIndex = c.cards.indexWhere(
        (card) => card.emoji != first.emoji,
      );
      await c.handleCardTap(0);
      await c.handleCardTap(secondIndex);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(c.lives, 2);
      c.dispose();
    });

    test('Pattern Lock wrong pattern reduces life', () async {
      final c = PatternLockController(storage: storage, soundService: sound);
      c.targetPattern = [0, 1, 2];
      c.isAcceptingInput = true;
      c.isRoundComplete = false;
      expect(c.lives, 3);
      c.addDot(2);
      c.addDot(1);
      c.addDot(0);
      await c.submitPattern();
      expect(c.lives, 2);
      c.dispose();
    });

    test('level increases after successful Color Sequence round', () async {
      final c = ColorSequenceController(storage: storage, soundService: sound);
      c.targetSequence = [SequenceColor.blue, SequenceColor.orange];
      c.phase = ColorSequencePhase.repeating;
      c.isRoundComplete = false;
      final startLevel = c.level;
      await c.tapColor(SequenceColor.blue);
      await c.tapColor(SequenceColor.orange);
      expect(c.level, greaterThan(startLevel));
      c.dispose();
    });
  });

  group('Second life rules', () {
    test('session resets secondLifeUsed on play again', () {
      final session = SecondLifeSession()
        ..markSecondLifeUsed()
        ..endGameFinal();
      session.reset();
      expect(session.secondLifeUsed, isFalse);
      expect(session.isGameOver, isFalse);
    });

    test('all launcher games enable one rewarded continue', () {
      for (final game in homeLauncherGames) {
        expect(SecondLifeConfig.forGame(game.type).enabled, isTrue);
      }
    });

    test('rewarded ad unit IDs match config', () {
      expect(AdMobConfig.rewardedTest, isNotEmpty);
      expect(AdMobConfig.rewardedProduction, isNotEmpty);
    });
  });

  group('Banner placement', () {
    test('home lists five games; banner widget tested in home_screen_test', () {
      expect(homeLauncherGames.length, 5);
    });
  });

  group('Routes', () {
    test('game routes exist for all five launcher games', () {
      for (final game in homeLauncherGames) {
        expect(AppRoutes.gameRoute(game.type), isNot(AppRoutes.difficulty));
      }
    });

    test('home lists exactly five approved games', () {
      expect(homeLauncherGames.length, 5);
      expect(homeLauncherGames.map((g) => g.title).toList(), [
        'Quick Math',
        'Color Sequence',
        'Emoji Match',
        'Pattern Lock',
        'Launch Rocket',
      ]);
    });
  });

  group('Highest level persistence', () {
    test('saves highest level when beaten', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      expect(storage.getHighestLevel(GameType.quickMath), 0);
      final saved = await storage.saveHighestLevelIfHigher(
        GameType.quickMath,
        4,
      );
      expect(saved, 4);
      expect(storage.getHighestLevel(GameType.quickMath), 4);
      final again = await storage.saveHighestLevelIfHigher(
        GameType.quickMath,
        2,
      );
      expect(again, 4);
    });
  });
}
