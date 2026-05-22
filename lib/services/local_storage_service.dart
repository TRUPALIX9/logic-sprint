import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_model.dart';

class LocalStorageService {
  LocalStorageService._(this._preferences);

  static const String soundKey = 'isSoundEnabled';
  static const String vibrationKey = 'isVibrationEnabled';
  static const String themeModeKey = 'themeMode';
  static const String playerNameKey = 'playerName';
  static const String scoreHistoryKey = 'scoreHistoryJson';
  static const String pendingSubmissionsKey = 'pendingAllTimeSubmissionsJson';
  static const String submittedBestPrefix = 'submittedAllTimeBest_';
  static const String leaderboardCachePrefix = 'leaderboardCache_';
  static const String leaderboardFetchedDatePrefix = 'leaderboardFetchedDate_';
  static const String highestLevelPrefix = 'highestLevel_';

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
      await _preferences.remove(_highestLevelKey(gameType));
    }
  }

  int getHighestLevel(GameType gameType) {
    return _preferences.getInt(_highestLevelKey(gameType)) ?? 0;
  }

  Future<int> saveHighestLevelIfHigher(GameType gameType, int level) async {
    final key = _highestLevelKey(gameType);
    final current = _preferences.getInt(key) ?? 0;
    if (level > current) {
      await _preferences.setInt(key, level);
      return level;
    }
    return current;
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

  String _highestLevelKey(GameType gameType) {
    return '$highestLevelPrefix${gameType.storageKey}';
  }

  String? getPlayerName() => _preferences.getString(playerNameKey);

  Future<void> setPlayerName(String value) =>
      _preferences.setString(playerNameKey, value);

  int getSubmittedAllTimeBest(GameType gameType) {
    return _preferences.getInt(
          '${submittedBestPrefix}${gameType.storageKey}',
        ) ??
        0;
  }

  Future<void> setSubmittedAllTimeBest(GameType gameType, int score) async {
    await _preferences.setInt(
      '${submittedBestPrefix}${gameType.storageKey}',
      score,
    );
  }

  String? getLeaderboardCacheJson(GameType gameType) {
    return _preferences.getString(
      '${leaderboardCachePrefix}${gameType.storageKey}',
    );
  }

  Future<void> setLeaderboardCacheJson(GameType gameType, String value) async {
    await _preferences.setString(
      '${leaderboardCachePrefix}${gameType.storageKey}',
      value,
    );
  }

  String? getLeaderboardLastFetchedDate(GameType gameType) {
    return _preferences.getString(
      '${leaderboardFetchedDatePrefix}${gameType.storageKey}',
    );
  }

  Future<void> setLeaderboardLastFetchedDate(
    GameType gameType,
    String dateKey,
  ) async {
    await _preferences.setString(
      '${leaderboardFetchedDatePrefix}${gameType.storageKey}',
      dateKey,
    );
  }

  bool isLeaderboardFetchedToday(GameType gameType) {
    return getLeaderboardLastFetchedDate(gameType) == _todayKey();
  }

  String? getScoreHistoryJson() => _preferences.getString(scoreHistoryKey);

  Future<void> setScoreHistoryJson(String value) =>
      _preferences.setString(scoreHistoryKey, value);

  String? getPendingSubmissionsJson() =>
      _preferences.getString(pendingSubmissionsKey);

  Future<void> setPendingSubmissionsJson(String value) =>
      _preferences.setString(pendingSubmissionsKey, value);

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
