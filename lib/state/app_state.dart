import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../games/rocket_launch/rocket_look.dart';
import '../games/round_engine.dart';
import '../models/game.dart';
import '../models/round_result.dart';
import '../services/storage.dart';

/// Settings, personal bests, and round feedback (haptics + click sounds).
class AppState extends ChangeNotifier implements RoundFeedback {
  AppState(this.storage)
    : _soundOn = storage.soundOn,
      _vibrationOn = storage.vibrationOn;

  final Storage storage;
  bool _soundOn;
  bool _vibrationOn;

  bool get soundOn => _soundOn;
  bool get vibrationOn => _vibrationOn;

  int best(GameId game, Difficulty difficulty) =>
      storage.best(game, difficulty);

  /// How long the best-scoring run took, if recorded.
  Duration? bestTime(GameId game, Difficulty difficulty) =>
      storage.bestTime(game, difficulty);

  int plays(GameId game, Difficulty difficulty) =>
      storage.plays(game, difficulty);

  /// Runs finished on this device, all games.
  int get totalPlays => [
    for (final game in GameId.values)
      for (final difficulty in Difficulty.values) plays(game, difficulty),
  ].fold(0, (sum, n) => sum + n);

  (GameId, Difficulty)? get lastPlayed => storage.lastPlayed;

  // Hearts: no free hearts. Every finished run unlocks one rewarded ad worth
  // a heart (up to [maxHearts]). Spent to revive a run in any game.
  static const maxHearts = 5;

  int get hearts => storage.hearts;
  bool get heartsFull => hearts >= maxHearts;

  /// A finished run has unlocked a heart ad that hasn't been watched yet.
  bool get heartAdUnlocked => storage.heartAdUnlocked;

  /// The heart ad can be offered right now (unlocked and room for a heart).
  bool get canEarnHeart => heartAdUnlocked && !heartsFull;

  /// Spends one heart. False when there are none.
  Future<bool> useHeart() async {
    if (hearts <= 0) {
      return false;
    }
    await storage.setHearts(hearts - 1);
    notifyListeners();
    return true;
  }

  /// Reward for the heart ad; uses up the run's unlock.
  Future<void> earnHeart() async {
    if (!canEarnHeart) {
      return;
    }
    await storage.setHearts(hearts + 1);
    await storage.setHeartAdUnlocked(false);
    notifyListeners();
  }

  ShipKind get rocketShip => ShipKind.parse(storage.rocketShip);

  Future<void> setRocketShip(ShipKind kind) async {
    await storage.setRocketShip(kind.name);
    notifyListeners();
  }

  Future<void> setSoundOn(bool value) async {
    _soundOn = value;
    await storage.setSoundOn(value);
    notifyListeners();
  }

  Future<void> setVibrationOn(bool value) async {
    _vibrationOn = value;
    await storage.setVibrationOn(value);
    notifyListeners();
  }

  /// Saves the best score, play count and "last played" for a finished round,
  /// and unlocks that run's heart ad.
  Future<void> recordRound(RoundResult result) async {
    await storage.addPlay(result.game, result.difficulty);
    await storage.setHeartAdUnlocked(true);
    await storage.saveBestIfHigher(
      result.game,
      result.difficulty,
      result.score,
      duration: result.game.tracksTime ? result.duration : null,
    );
    await storage.setLastPlayed(result.game, result.difficulty);
    notifyListeners();
  }

  Future<void> resetBests() async {
    await storage.resetBests();
    notifyListeners();
  }

  @override
  void tap() {
    if (_vibrationOn) {
      HapticFeedback.selectionClick();
    }
    if (_soundOn) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void correct() {
    if (_vibrationOn) {
      HapticFeedback.lightImpact();
    }
    if (_soundOn) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void wrong() {
    if (_vibrationOn) {
      HapticFeedback.heavyImpact();
    }
  }
}
