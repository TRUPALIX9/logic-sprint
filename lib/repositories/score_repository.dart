import 'dart:convert';

import '../core/constants/app_config.dart';
import '../core/constants/life_game_constants.dart';
import '../models/game_model.dart';
import '../models/leaderboard_entry.dart';
import '../models/score_model.dart';
import '../services/local_storage_service.dart';

/// Local score history, bests, submitted bests, and leaderboard cache.
class ScoreRepository {
  ScoreRepository(this._storage);

  final LocalStorageService _storage;
  static const DifficultyLevel _bestDifficulty =
      LifeGameConstants.storageDifficulty;

  Future<int> getBestScore(GameType gameType) async {
    return _storage.getHighScore(gameType, _bestDifficulty);
  }

  Future<void> updateBestScore(GameType gameType, int score) async {
    await _storage.saveHighScoreIfHigher(gameType, _bestDifficulty, score);
  }

  Future<int> getSubmittedAllTimeBest(GameType gameType) async {
    return _storage.getSubmittedAllTimeBest(gameType);
  }

  Future<void> updateSubmittedAllTimeBest(GameType gameType, int score) async {
    await _storage.setSubmittedAllTimeBest(gameType, score);
  }

  Future<void> saveScore(ScoreModel score) async {
    final raw = _storage.getScoreHistoryJson();
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          list.add(Map<String, dynamic>.from(item as Map));
        }
      } on Object {
        // Reset corrupt history.
      }
    }
    list.add(score.toHistoryJson());
    if (list.length > AppConfig.maxScoreHistoryEntries) {
      list.removeRange(0, list.length - AppConfig.maxScoreHistoryEntries);
    }
    await _storage.setScoreHistoryJson(jsonEncode(list));
  }

  Future<List<LeaderboardEntry>> getCachedLeaderboard(GameType gameType) async {
    final raw = _storage.getLeaderboardCacheJson(gameType);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => LeaderboardEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<void> saveCachedLeaderboard(
    GameType gameType,
    List<LeaderboardEntry> entries,
  ) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.setLeaderboardCacheJson(gameType, encoded);
    await _storage.setLeaderboardLastFetchedDate(gameType, _todayKey());
  }

  String? getLeaderboardLastFetchedDate(GameType gameType) {
    return _storage.getLeaderboardLastFetchedDate(gameType);
  }

  bool shouldAutoFetchLeaderboard(GameType gameType) {
    return !_storage.isLeaderboardFetchedToday(gameType);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
