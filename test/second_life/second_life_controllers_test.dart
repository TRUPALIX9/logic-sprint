import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/models/second_life_config.dart';
import 'package:logic_sprint/models/second_life_session.dart';
import 'package:logic_sprint/screens/games/color_sequence/color_sequence_controller.dart';
import 'package:logic_sprint/screens/games/emoji_match/emoji_match_controller.dart';
import 'package:logic_sprint/screens/games/pattern_lock/pattern_lock_controller.dart';
import 'package:logic_sprint/screens/games/quick_math/quick_math_controller.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:logic_sprint/services/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SoundService soundService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
    soundService = SoundService.silent();
  });

  group('SecondLifeConfig', () {
    test('all launcher games enable second life with shared button label', () {
      for (final type in homeLauncherGames.map((g) => g.type)) {
        final config = SecondLifeConfig.forGame(type);
        expect(config.enabled, isTrue);
        expect(config.continueButtonLabel, SecondLifeConfig.watchAdButtonLabel);
      }
    });
  });

  group('SecondLifeSession', () {
    test('starts with second life available', () {
      final session = SecondLifeSession();
      expect(session.secondLifeUsed, isFalse);
      expect(session.awaitingSecondLifeDecision, isFalse);
    });

    test('hides watch ad after second life is used', () {
      final session = SecondLifeSession()..pauseForSecondLifeOffer();
      expect(session.canOfferSecondLife, isTrue);
      session.markSecondLifeUsed();
      expect(session.canOfferSecondLife, isFalse);
      expect(session.secondLifeUsed, isTrue);
    });

    test('reset clears second life for play again', () {
      final session = SecondLifeSession()
        ..markSecondLifeUsed()
        ..endGameFinal();
      session.reset();
      expect(session.secondLifeUsed, isFalse);
      expect(session.isGameOver, isFalse);
    });
  });

  group('Quick Math second life', () {
    test(
      'wrong answers cost lives until game over offers second life',
      () async {
        final controller = QuickMathController(
          storage: storage,
          soundService: soundService,
          random: Random(1),
        );
        await controller.initialize();
        expect(controller.secondLife.secondLifeUsed, isFalse);

        final wrong = controller.currentQuestion!.options.firstWhere(
          (o) => o != controller.currentQuestion!.correctAnswer,
        );

        for (var i = 0; i < 3; i++) {
          await controller.submitAnswer(wrong);
          if (i < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        }

        expect(controller.lives, 0);
        expect(controller.secondLife.awaitingSecondLifeDecision, isTrue);
        expect(controller.isRoundComplete, isFalse);
        controller.dispose();
      },
    );

    test('resume keeps score and refreshes question', () async {
      final controller = QuickMathController(
        storage: storage,
        soundService: soundService,
        random: Random(2),
      );
      await controller.initialize();
      controller.score = 25;
      await controller.resumeFromSecondLifeReward();

      expect(controller.secondLife.secondLifeUsed, isTrue);
      expect(controller.score, 25);
      expect(controller.isAnswerLocked, isFalse);
      expect(controller.currentQuestion, isNotNull);
      controller.dispose();
    });
  });

  group('Color Sequence second life', () {
    test('resume replays current sequence without advancing level', () async {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        random: Random(4),
      );
      controller.targetSequence = [SequenceColor.blue, SequenceColor.orange];
      controller.level = 3;
      controller.score = 30;

      await controller.resumeFromSecondLifeReward();

      expect(controller.secondLife.secondLifeUsed, isTrue);
      expect(controller.score, 30);
      expect(controller.level, 3);
      expect(controller.targetSequence, [
        SequenceColor.blue,
        SequenceColor.orange,
      ]);
      controller.dispose();
    });
  });

  group('Emoji Match second life', () {
    test('resume restores one life and keeps score', () async {
      final controller = EmojiMatchController(
        storage: storage,
        soundService: soundService,
        random: Random(3),
      );
      await controller.initialize();
      controller.score = 12;
      controller.lives = 0;
      controller.secondLife.pauseForSecondLifeOffer();

      await controller.resumeFromSecondLifeReward();

      expect(controller.secondLife.secondLifeUsed, isTrue);
      expect(controller.score, 12);
      expect(controller.lives, 1);
      expect(controller.isRoundComplete, isFalse);
      controller.dispose();
    });

    test('play again resets second life', () async {
      final controller = EmojiMatchController(
        storage: storage,
        soundService: soundService,
      );
      await controller.initialize();
      controller.secondLife.markSecondLifeUsed();
      controller.resetGame();
      expect(controller.secondLife.secondLifeUsed, isFalse);
      controller.dispose();
    });
  });

  group('Pattern Lock second life', () {
    test('last life wrong pattern offers second life', () async {
      final controller = PatternLockController(
        storage: storage,
        soundService: soundService,
        random: Random(9),
      );
      await controller.initialize();
      controller.lives = 1;
      controller.targetPattern = [0, 1, 2];
      controller.playerPattern = [0, 1, 3];
      controller.isAcceptingInput = true;

      await controller.submitPattern();

      expect(controller.secondLife.awaitingSecondLifeDecision, isTrue);
      expect(controller.isRoundComplete, isFalse);
      controller.dispose();
    });

    test('resume restores a life and keeps score', () async {
      final controller = PatternLockController(
        storage: storage,
        soundService: soundService,
        random: Random(1),
      );
      controller.score = 40;
      controller.lives = 0;
      controller.targetPattern = [0, 2, 4];

      await controller.resumeFromSecondLifeReward();

      expect(controller.secondLife.secondLifeUsed, isTrue);
      expect(controller.score, 40);
      expect(controller.lives, 1);
      expect(controller.isAcceptingInput, isTrue);
      controller.dispose();
    });
  });
}
