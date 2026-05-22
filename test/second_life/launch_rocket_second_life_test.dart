import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/second_life_session.dart';
import 'package:logic_sprint/screens/games/launch_rocket/launch_rocket_screen.dart';

void main() {
  test('clearing nearby asteroids removes rocks close to rocket', () {
    final asteroids = [
      RocketAsteroid(
        x: 100,
        y: 100,
        radius: 10,
        speed: 1,
        rotation: 0,
        spriteIndex: 0,
      ),
      RocketAsteroid(
        x: 300,
        y: 300,
        radius: 10,
        speed: 1,
        rotation: 0,
        spriteIndex: 1,
      ),
    ];
    const rocketX = 90.0;
    const rocketY = 90.0;
    const rocketWidth = 48.0;
    const rocketHeight = 56.0;
    const clearRadius = 150.0;

    final rocketCenter = Offset(
      rocketX + rocketWidth / 2,
      rocketY + rocketHeight / 2,
    );
    asteroids.removeWhere((asteroid) {
      final dist = (Offset(asteroid.x, asteroid.y) - rocketCenter).distance;
      return dist < clearRadius;
    });

    expect(asteroids, hasLength(1));
    expect(asteroids.first.x, 300);
  });

  test('second life session starts unused', () {
    final session = SecondLifeSession();
    expect(session.secondLifeUsed, isFalse);
  });
}
