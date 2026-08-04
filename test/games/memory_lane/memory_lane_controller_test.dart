import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/memory_lane/memory_lane_controller.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:logic_sprint/services/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MemoryLaneController', () {
    late LocalStorageService storage;
    late SoundService soundService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      soundService = SoundService.silent();
    });

    test('initializes dimensions and starts sequence length by difficulty', () async {
      final easyController = MemoryLaneController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.easy,
      );
      await easyController.initialize();
      expect(easyController.gridSize, 3);
      expect(easyController.sequenceLength, 3);

      final mediumController = MemoryLaneController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.medium,
      );
      await mediumController.initialize();
      expect(mediumController.gridSize, 4);
      expect(mediumController.sequenceLength, 4);

      final hardController = MemoryLaneController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.hard,
      );
      await hardController.initialize();
      expect(hardController.gridSize, 5);
      expect(hardController.sequenceLength, 5);
    });

    test('isTouchEnabled is disabled during flashing step playback', () async {
      final controller = MemoryLaneController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.easy,
      );

      // Initialize handles sequence flashing asynchronously, so touch starts disabled/flashing
      await controller.initialize();
      expect(controller.isTouchEnabled, isFalse);
    });
  });
}
