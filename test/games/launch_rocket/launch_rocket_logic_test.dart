import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/launch_rocket/launch_rocket_screen.dart';

void main() {
  test('RocketAsteroid stores position and motion fields', () {
    final asteroid = RocketAsteroid(
      x: 10,
      y: 20,
      radius: 12,
      speed: 3,
      rotation: 0.5,
    );
    asteroid.y += 5;
    asteroid.rotation += 0.1;

    expect(asteroid.x, 10);
    expect(asteroid.y, 25);
    expect(asteroid.radius, 12);
    expect(asteroid.speed, 3);
    expect(asteroid.rotation, closeTo(0.6, 0.001));
  });

  test('home launcher excludes True or False', () {
    expect(
      homeLauncherGames.map((g) => g.type),
      isNot(contains(GameType.trueFalse)),
    );
    expect(homeLauncherGames.length, 5);
  });
}
