import '../../models/game_model.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String gameSelect = '/game-select';
  static const String difficulty = '/difficulty';
  static const String quickMath = '/games/quick-math';
  static const String numberSequence = '/games/number-sequence';
  static const String trueFalse = '/games/true-false';
  static const String result = '/result';
  static const String highScores = '/high-scores';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String privacyPolicy = '/privacy-policy';

  static String gameRoute(GameType gameType) {
    switch (gameType) {
      case GameType.quickMath:
        return quickMath;
      case GameType.numberSequence:
        return numberSequence;
      case GameType.trueFalse:
        return trueFalse;
      case GameType.memoryPattern:
      case GameType.colorConfusion:
        return gameSelect;
    }
  }
}
