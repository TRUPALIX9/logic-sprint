import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/color_sequence/color_sequence_controller.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:logic_sprint/services/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorSequenceController', () {
    late LocalStorageService storage;
    late SoundService soundService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      soundService = SoundService.silent();
    });

    test('starting sequence length follows difficulty', () {
      expect(
        ColorSequenceController.startingSequenceLengthFor(DifficultyLevel.easy),
        3,
      );
      expect(
        ColorSequenceController.startingSequenceLengthFor(DifficultyLevel.medium),
        4,
      );
      expect(
        ColorSequenceController.startingSequenceLengthFor(DifficultyLevel.hard),
        5,
      );
    });

    test('generateSequence uses only palette colors', () {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.easy,
        random: Random(3),
      );

      final sequence = controller.generateSequence(6);
      expect(sequence, hasLength(6));
      for (final color in sequence) {
        expect(ColorSequenceController.palette, contains(color));
      }
      controller.dispose();
    });

    test('wrong tap increments wrong answers', () async {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.easy,
        random: Random(7),
      );

      controller.sequenceLength = 2;
      controller.targetSequence = [SequenceColor.cyan, SequenceColor.purple];
      controller.phase = ColorSequencePhase.repeating;
      controller.isRoundComplete = false;

      await controller.tapColor(SequenceColor.blue);
      expect(controller.wrongAnswers, 1);
      expect(controller.currentStreak, 0);
      controller.dispose();
    });

    test('correct full sequence adds score', () async {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.easy,
        random: Random(5),
      );

      controller.sequenceLength = 2;
      controller.targetSequence = [SequenceColor.blue, SequenceColor.orange];
      controller.phase = ColorSequencePhase.repeating;
      controller.isRoundComplete = false;

      await controller.tapColor(SequenceColor.blue);
      await controller.tapColor(SequenceColor.orange);

      expect(controller.score, greaterThanOrEqualTo(10));
      expect(controller.correctAnswers, 1);
      expect(controller.completedRounds, 1);
      controller.dispose();
    });

    test('high score key uses colorSequence storage key', () async {
      await storage.saveHighScoreIfHigher(
        GameType.colorSequence,
        DifficultyLevel.easy,
        40,
      );
      expect(
        storage.getHighScore(GameType.colorSequence, DifficultyLevel.easy),
        40,
      );
    });
  });

  group('GameType storage', () {
    test('launch games include colorSequence with correct storage key', () {
      expect(GameType.values, contains(GameType.colorSequence));
      expect(GameType.colorSequence.storageKey, 'colorSequence');
      expect(availableGames, hasLength(3));
      expect(
        availableGames.map((game) => game.type),
        containsAll([
          GameType.quickMath,
          GameType.colorSequence,
          GameType.trueFalse,
        ]),
      );
    });
  });
}
