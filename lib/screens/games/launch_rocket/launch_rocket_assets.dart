/// Asset paths for Launch Rocket (`assets/rocket-launch/`).
abstract final class LaunchRocketAssets {
  static const String folder = 'assets/rocket-launch';

  static const String rocket = '$folder/rocket.jpg';

  static const List<String> asteroids = [
    '$folder/asteroid_01.png',
    '$folder/asteroid_02.jpeg',
    '$folder/asteroid_03.jpeg',
    '$folder/asteroid_04.jpeg',
    '$folder/asteroid_05.png',
    '$folder/asteroid_06.png',
    '$folder/asteroid_07.png',
  ];

  static List<String> get all => [rocket, ...asteroids];
}
