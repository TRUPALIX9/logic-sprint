import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  (GameId, Difficulty)? get lastPlayed => storage.lastPlayed;

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

  /// Saves the best score and "last played" for a finished round.
  Future<void> recordRound(RoundResult result) async {
    await storage.saveBestIfHigher(
      result.game,
      result.difficulty,
      result.score,
      duration: result.duration,
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
