/// Tracks rewarded second-life state for a single game run.
class SecondLifeSession {
  bool secondLifeUsed = false;
  bool isPausedForRewardAd = false;
  bool awaitingSecondLifeDecision = false;
  bool isGameOver = false;

  bool get canOfferSecondLife =>
      enabled && awaitingSecondLifeDecision && !secondLifeUsed;

  bool enabled = true;

  void pauseForSecondLifeOffer() {
    awaitingSecondLifeDecision = true;
    isGameOver = true;
  }

  void markSecondLifeUsed() {
    secondLifeUsed = true;
    awaitingSecondLifeDecision = false;
    isPausedForRewardAd = false;
    isGameOver = false;
  }

  void resumeAfterReward() {
    awaitingSecondLifeDecision = false;
    isPausedForRewardAd = false;
    isGameOver = false;
  }

  void endGameFinal() {
    awaitingSecondLifeDecision = false;
    isPausedForRewardAd = false;
    isGameOver = true;
  }

  void reset() {
    secondLifeUsed = false;
    isPausedForRewardAd = false;
    awaitingSecondLifeDecision = false;
    isGameOver = false;
  }
}
