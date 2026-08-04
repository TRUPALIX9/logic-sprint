import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/rocket_launch/rocket_launch_controller.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:logic_sprint/services/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RocketLaunchController', () {
    late LocalStorageService storage;
    late SoundService soundService;
    late RocketLaunchController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      soundService = SoundService.silent();
      controller = RocketLaunchController(
        storage: storage,
        soundService: soundService,
        difficulty: DifficultyLevel.easy,
      );
    });

    test('initializes with default starting values', () async {
      expect(controller.isLoading, isTrue);
      await controller.initialize();
      expect(controller.isLoading, isFalse);
      expect(controller.score, 0);
      expect(controller.correctAnswers, 0);
      expect(controller.wrongAnswers, 0);
      expect(controller.rocketX, 0.5);
    });

    test('steer rocket moves coordinates correctly', () async {
      await controller.initialize();
      expect(controller.rocketX, 0.5);

      controller.moveRocketLeft();
      expect(controller.rocketX, lessThan(0.5));

      controller.moveRocketRight();
      controller.moveRocketRight();
      expect(controller.rocketX, greaterThan(0.45));
    });

    test('direct moveTo clamps values properly', () async {
      await controller.initialize();
      controller.moveRocketTo(1.5);
      expect(controller.rocketX, 0.95);

      controller.moveRocketTo(-0.5);
      expect(controller.rocketX, 0.05);
    });
  });
}
