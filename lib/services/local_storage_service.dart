import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_config.dart';
import '../models/game_model.dart';

class LocalStorageService {
  LocalStorageService._(this._preferences);

  static const String soundKey = 'isSoundEnabled';
  static const String vibrationKey = 'isVibrationEnabled';
  static const String themeModeKey = 'themeMode';
  static const String playerNameKey = 'playerName';
  static const String leaderboardCacheJsonKey = 'leaderboardCacheJson';
  static const String leaderboardCacheTimestampKey =
      'leaderboardCacheTimestamp';
  static const String leaderboardLastRefreshKey = 'leaderboardLastRefreshAt';
  static const String leaderboardSubmissionDateKey =
      'leaderboardSubmissionDate';
  static const String leaderboardSubmissionCountKey =
      'leaderboardSubmissionCount';

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

  String? getPlayerName() => _preferences.getString(playerNameKey);

  Future<void> setPlayerName(String value) =>
      _preferences.setString(playerNameKey, value);

  String? getLeaderboardCacheJson() =>
      _preferences.getString(leaderboardCacheJsonKey);

  Future<void> setLeaderboardCacheJson(String value) =>
      _preferences.setString(leaderboardCacheJsonKey, value);

  DateTime? getLeaderboardCacheTimestamp() {
    final millis = _preferences.getInt(leaderboardCacheTimestampKey);
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLeaderboardCacheTimestamp(DateTime value) => _preferences
      .setInt(leaderboardCacheTimestampKey, value.millisecondsSinceEpoch);

  DateTime? getLeaderboardLastRefreshAt() {
    final millis = _preferences.getInt(leaderboardLastRefreshKey);
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLeaderboardLastRefreshAt(DateTime value) => _preferences
      .setInt(leaderboardLastRefreshKey, value.millisecondsSinceEpoch);

  bool canSubmitLeaderboardToday() =>
      remainingLeaderboardSubmissionsToday() > 0;

  int remainingLeaderboardSubmissionsToday() {
    _resetLeaderboardSubmissionsIfNewDay();
    final count = _preferences.getInt(leaderboardSubmissionCountKey) ?? 0;
    return (AppConfig.maxDailyLeaderboardSubmissions - count).clamp(
      0,
      AppConfig.maxDailyLeaderboardSubmissions,
    );
  }

  Future<void> recordLeaderboardSubmission() async {
    _resetLeaderboardSubmissionsIfNewDay();
    final count = _preferences.getInt(leaderboardSubmissionCountKey) ?? 0;
    await _preferences.setInt(leaderboardSubmissionCountKey, count + 1);
    await _preferences.setString(leaderboardSubmissionDateKey, _todayKey());
  }

  void _resetLeaderboardSubmissionsIfNewDay() {
    final storedDate = _preferences.getString(leaderboardSubmissionDateKey);
    if (storedDate != _todayKey()) {
      _preferences.setInt(leaderboardSubmissionCountKey, 0);
      _preferences.setString(leaderboardSubmissionDateKey, _todayKey());
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
