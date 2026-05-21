import 'dart:convert';

import '../core/constants/app_config.dart';
import '../models/leaderboard_score_model.dart';
import 'local_storage_service.dart';

class LeaderboardCacheService {
  LeaderboardCacheService(this._storage);

  final LocalStorageService _storage;

  static const Duration cacheTtl = Duration(
    minutes: AppConfig.leaderboardCacheMinutes,
  );
  static const Duration refreshCooldown = Duration(
    seconds: AppConfig.leaderboardRefreshCooldownSeconds,
  );

  List<LeaderboardScoreModel>? loadScores() {
    final raw = _storage.getLeaderboardCacheJson();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => LeaderboardScoreModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on Object {
      return null;
    }
  }

  Future<void> saveScores(List<LeaderboardScoreModel> scores) async {
    final encoded = jsonEncode(scores.map((score) => score.toJson()).toList());
    await _storage.setLeaderboardCacheJson(encoded);
    await _storage.setLeaderboardCacheTimestamp(DateTime.now());
  }

  DateTime? get cacheTimestamp => _storage.getLeaderboardCacheTimestamp();

  bool get hasCache => loadScores() != null && loadScores()!.isNotEmpty;

  bool isCacheValid() {
    final timestamp = cacheTimestamp;
    if (timestamp == null) {
      return false;
    }
    return DateTime.now().difference(timestamp) < cacheTtl;
  }

  bool canRefreshNow() {
    final lastRefresh = _storage.getLeaderboardLastRefreshAt();
    if (lastRefresh == null) {
      return true;
    }
    return DateTime.now().difference(lastRefresh) >= refreshCooldown;
  }

  Duration? refreshCooldownRemaining() {
    final lastRefresh = _storage.getLeaderboardLastRefreshAt();
    if (lastRefresh == null) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(lastRefresh);
    if (elapsed >= refreshCooldown) {
      return Duration.zero;
    }
    return refreshCooldown - elapsed;
  }

  Future<void> markRefreshAttempt() async {
    await _storage.setLeaderboardLastRefreshAt(DateTime.now());
  }
}
