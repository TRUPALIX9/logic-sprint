import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_model.dart';

class LocalStorageService {
  LocalStorageService._(this._preferences);

  static const String soundKey = 'isSoundEnabled';
  static const String vibrationKey = 'isVibrationEnabled';
  static const String themeModeKey = 'themeMode';

  final SharedPreferences _preferences;

  static Future<LocalStorageService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalStorageService._(preferences);
  }

  int getHighScore(GameType gameType, DifficultyLevel difficulty) {
    return _preferences.getInt(_highScoreKey(gameType, difficulty)) ?? 0;
  }

  Future<int> saveHighScoreIfHigher(
    GameType gameType,
    DifficultyLevel difficulty,
    int newScore,
  ) async {
    final key = _highScoreKey(gameType, difficulty);
    final currentBest = _preferences.getInt(key) ?? 0;
    final best = newScore > currentBest ? newScore : currentBest;
    if (best != currentBest) {
      await _preferences.setInt(key, best);
    }
    return best;
  }

  Future<void> resetHighScores() async {
    for (final gameType in GameType.values.where((game) => game.isPlayable)) {
      for (final difficulty in DifficultyLevel.values) {
        await _preferences.remove(_highScoreKey(gameType, difficulty));
      }
    }
  }

  bool getSoundEnabled() => _preferences.getBool(soundKey) ?? true;

  Future<void> setSoundEnabled(bool value) =>
      _preferences.setBool(soundKey, value);

  bool getVibrationEnabled() => _preferences.getBool(vibrationKey) ?? true;

  Future<void> setVibrationEnabled(bool value) =>
      _preferences.setBool(vibrationKey, value);

  ThemeMode getThemeMode() {
    switch (_preferences.getString(themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) {
    final value = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _preferences.setString(themeModeKey, value);
  }

  String _highScoreKey(GameType gameType, DifficultyLevel difficulty) {
    return 'highScore_${gameType.storageKey}_${difficulty.storageKey}';
  }
}
