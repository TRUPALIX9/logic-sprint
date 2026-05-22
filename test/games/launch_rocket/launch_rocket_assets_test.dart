import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/screens/games/launch_rocket/launch_rocket_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LaunchRocketAssets', () {
    test('defines rocket and seven asteroid sprites', () {
      expect(LaunchRocketAssets.rocket, 'assets/rocket-launch/rocket.jpg');
      expect(LaunchRocketAssets.asteroids, hasLength(7));
      expect(LaunchRocketAssets.asteroids.first, endsWith('asteroid_01.png'));
      expect(LaunchRocketAssets.asteroids.last, endsWith('asteroid_07.png'));
    });

    test('all asset paths use snake_case asteroid names', () {
      for (final path in LaunchRocketAssets.asteroids) {
        expect(path, contains('asteroid_'));
        expect(path, isNot(contains('Astroid')));
        expect(path, isNot(contains('Asroid')));
        expect(path, isNot(contains('Astorid')));
      }
    });
  });
}
