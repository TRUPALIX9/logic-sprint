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

    test('sequence length grows with level', () {
      expect(ColorSequenceController.sequenceLengthForLevel(1), 2);
      expect(ColorSequenceController.sequenceLengthForLevel(3), 4);
    });

    test('generateSequence uses only palette colors', () {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        random: Random(3),
      );

      final sequence = controller.generateSequence(6);
      expect(sequence, hasLength(6));
      for (final color in sequence) {
        expect(ColorSequenceController.palette, contains(color));
      }
      controller.dispose();
    });

    test('wrong tap increments wrong answers and costs a life', () async {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        random: Random(7),
      );

      controller.targetSequence = [SequenceColor.cyan, SequenceColor.purple];
      controller.phase = ColorSequencePhase.repeating;
      controller.isRoundComplete = false;

      await controller.tapColor(SequenceColor.blue);
      expect(controller.wrongAnswers, 1);
      expect(controller.currentStreak, 0);
      expect(controller.lives, 2);
      expect(controller.isRoundComplete, isFalse);
      controller.dispose();
    });

    test('correct full sequence adds score and level', () async {
      final controller = ColorSequenceController(
        storage: storage,
        soundService: soundService,
        random: Random(5),
      );

      controller.targetSequence = [SequenceColor.blue, SequenceColor.orange];
      controller.phase = ColorSequencePhase.repeating;
      controller.isRoundComplete = false;

      await controller.tapColor(SequenceColor.blue);
      await controller.tapColor(SequenceColor.orange);

      expect(controller.score, greaterThanOrEqualTo(10));
      expect(controller.correctAnswers, 1);
      expect(controller.level, 2);
      controller.dispose();
    });
  });
}
