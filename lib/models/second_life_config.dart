import 'game_model.dart';

/// Per-game copy and flags for the rewarded second-life overlay.
class SecondLifeConfig {
  const SecondLifeConfig({
    required this.enabled,
    required this.rewardLabel,
    required this.continueButtonLabel,
    required this.failTitle,
    required this.failMessage,
  });

  final bool enabled;
  final String rewardLabel;
  final String continueButtonLabel;
  final String failTitle;
  final String failMessage;

  static const String watchAdButtonLabel = 'Watch Ad for Second Life';
  static const String helperText =
      'Continue this run after watching a rewarded ad.';
  static const String endGameLabel = 'End Game';
  static const String playAgainLabel = 'Play Again';
  static const String backToGamesLabel = 'Back to Games';
  static const String gameOverTitle = 'Game Over';

  static SecondLifeConfig forGame(GameType type) {
    switch (type) {
      case GameType.quickMath:
        return const SecondLifeConfig(
          enabled: true,
          rewardLabel: 'Skip the missed question and keep your score.',
          continueButtonLabel: watchAdButtonLabel,
          failTitle: 'Nice run!',
          failMessage: 'Watch an ad for one more chance this round.',
        );
      case GameType.colorSequence:
        return const SecondLifeConfig(
          enabled: true,
          rewardLabel: 'Replay the current color sequence.',
          continueButtonLabel: watchAdButtonLabel,
          failTitle: 'Wrong color!',
          failMessage: 'Get a second chance to repeat this pattern.',
        );
      case GameType.emojiMatch:
        return const SecondLifeConfig(
          enabled: true,
          rewardLabel: 'Restore one life and keep your current board.',
          continueButtonLabel: watchAdButtonLabel,
          failTitle: 'Out of lives!',
          failMessage: 'Watch an ad for one more chance this round.',
        );
      case GameType.patternLock:
        return const SecondLifeConfig(
          enabled: true,
          rewardLabel: 'See the pattern again and retry.',
          continueButtonLabel: watchAdButtonLabel,
          failTitle: 'Wrong pattern!',
          failMessage: 'Earn one more try on this pattern.',
        );
      case GameType.launchRocket:
        return const SecondLifeConfig(
          enabled: true,
          rewardLabel: 'Clear nearby rocks and brief shields.',
          continueButtonLabel: watchAdButtonLabel,
          failTitle: 'Rocket hit!',
          failMessage: 'Watch an ad to keep flying.',
        );
      case GameType.trueFalse:
        return const SecondLifeConfig(
          enabled: false,
          rewardLabel: '',
          continueButtonLabel: watchAdButtonLabel,
          failTitle: 'Game Over',
          failMessage: '',
        );
    }
  }
}
