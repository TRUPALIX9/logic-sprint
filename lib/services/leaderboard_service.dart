import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_config.dart';
import '../core/utils/player_name_validator.dart';
import '../models/game_model.dart';
import '../models/leaderboard_score_model.dart';
import 'leaderboard_cache_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

enum LeaderboardGameFilter { all, rocketLaunch, memoryLane }

enum LeaderboardDifficultyFilter { all, easy, medium, hard }

class LeaderboardLoadResult {
  const LeaderboardLoadResult({
    required this.scores,
    required this.fromCache,
    this.lastUpdated,
    this.errorMessage,
    this.infoMessage,
  });

  final List<LeaderboardScoreModel> scores;
  final bool fromCache;
  final DateTime? lastUpdated;
  final String? errorMessage;
  final String? infoMessage;
}

class LeaderboardSubmitResult {
  const LeaderboardSubmitResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

typedef SupabaseFetchScoresCallback = Future<List<LeaderboardScoreModel>?> Function();
typedef SupabaseInsertScoreCallback = Future<bool> Function({
  required String playerName,
  required int score,
  required String gameType,
  required String difficulty,
});

class LeaderboardService {
  LeaderboardService({
    required LocalStorageService storage,
    required LeaderboardCacheService cache,
    SupabaseFetchScoresCallback? fetchScores,
    SupabaseInsertScoreCallback? insertScore,
  })  : _storage = storage,
        _cache = cache,
        _fetchScoresOverride = fetchScores,
        _insertScoreOverride = insertScore;

  final LocalStorageService _storage;
  final LeaderboardCacheService _cache;
  final SupabaseFetchScoresCallback? _fetchScoresOverride;
  final SupabaseInsertScoreCallback? _insertScoreOverride;

  String? get savedPlayerName {
    final name = _storage.getPlayerName();
    if (name == null || name.isEmpty) {
      return null;
    }
    return name;
  }

  Future<void> savePlayerName(String name) async {
    final normalized = PlayerNameValidator.normalize(name);
    await _storage.setPlayerName(normalized);
  }

  bool canSubmitToday() => _storage.canSubmitLeaderboardToday();

  int remainingSubmissionsToday() =>
      _storage.remainingLeaderboardSubmissionsToday();

  static List<LeaderboardScoreModel> applyFilters(
    List<LeaderboardScoreModel> scores, {
    required LeaderboardGameFilter gameFilter,
    required LeaderboardDifficultyFilter difficultyFilter,
  }) {
    return scores.where((score) {
      if (gameFilter != LeaderboardGameFilter.all) {
        if (score.gameType != gameFilter.name) {
          return false;
        }
      }
      if (difficultyFilter != LeaderboardDifficultyFilter.all) {
        if (score.difficulty != difficultyFilter.name) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<LeaderboardLoadResult> loadLeaderboard({
    bool forceRefresh = false,
  }) async {
    final cached = _cache.loadScores();
    final cacheValid = _cache.isCacheValid();

    if (!forceRefresh && cacheValid && cached != null) {
      return LeaderboardLoadResult(
        scores: cached,
        fromCache: true,
        lastUpdated: _cache.cacheTimestamp,
      );
    }

    if (forceRefresh && !_cache.canRefreshNow()) {
      final remaining = _cache.refreshCooldownRemaining();
      final seconds = remaining?.inSeconds ?? 0;
      return LeaderboardLoadResult(
        scores: cached ?? const [],
        fromCache: true,
        lastUpdated: _cache.cacheTimestamp,
        infoMessage: seconds > 0 ? 'Refresh available in ${seconds}s.' : null,
      );
    }

    if (forceRefresh) {
      await _cache.markRefreshAttempt();
    }

    final remote = await _fetchTopScores();
    if (remote != null) {
      await _cache.saveScores(remote);
      return LeaderboardLoadResult(
        scores: remote,
        fromCache: false,
        lastUpdated: DateTime.now(),
      );
    }

    if (cached != null && cached.isNotEmpty) {
      return LeaderboardLoadResult(
        scores: cached,
        fromCache: true,
        lastUpdated: _cache.cacheTimestamp,
        errorMessage:
            'Online leaderboard is temporarily unavailable. Showing cached scores.',
      );
    }

    return const LeaderboardLoadResult(
      scores: [],
      fromCache: false,
      errorMessage: 'Online leaderboard is temporarily unavailable.',
    );
  }

  Future<LeaderboardSubmitResult> submitScore({
    required String playerName,
    required int score,
    required GameType gameType,
    required DifficultyLevel difficulty,
  }) async {
    if (score <= 0) {
      return const LeaderboardSubmitResult(
        success: false,
        message: 'Score must be greater than zero to submit.',
      );
    }

    final validationError = PlayerNameValidator.validate(playerName);
    if (validationError != null) {
      return LeaderboardSubmitResult(success: false, message: validationError);
    }

    if (!_storage.canSubmitLeaderboardToday()) {
      return const LeaderboardSubmitResult(
        success: false,
        message:
            'Daily leaderboard submission limit reached. Your local score is still saved.',
      );
    }

    try {
      if (_insertScoreOverride != null) {
        final ok = await _insertScoreOverride(
          playerName: playerName,
          score: score,
          gameType: gameType.storageKey,
          difficulty: difficulty.storageKey,
        );
        if (!ok) throw Object();
      } else {
        if (!AppSupabaseService.isAvailable) {
          return const LeaderboardSubmitResult(
            success: false,
            message:
                'Online leaderboard is temporarily unavailable. Your local score is saved.',
          );
        }
        await Supabase.instance.client.from('leaderboard_scores').insert({
          'player_name': PlayerNameValidator.normalize(playerName),
          'score': score,
          'game_type': gameType.storageKey,
          'difficulty': difficulty.storageKey,
          'app_version': AppConfig.appVersion,
        });
      }
      await _storage.recordLeaderboardSubmission();
      await savePlayerName(playerName);
      return const LeaderboardSubmitResult(
        success: true,
        message: 'Score submitted to the Global Leaderboard.',
      );
    } on Object {
      return const LeaderboardSubmitResult(
        success: false,
        message:
            'Online leaderboard is temporarily unavailable. Your local score is saved.',
      );
    }
  }

  Future<List<LeaderboardScoreModel>?> _fetchTopScores() async {
    if (_fetchScoresOverride != null) {
      return _fetchScoresOverride();
    }
    if (!AppSupabaseService.isAvailable) {
      return null;
    }

    try {
      final response = await Supabase.instance.client
          .from('leaderboard_scores')
          .select()
          .order('score', ascending: false)
          .limit(AppConfig.leaderboardLimit);

      return (response as List)
          .map((data) =>
              LeaderboardScoreModel.fromJson(data as Map<String, dynamic>))
          .toList(growable: false);
    } on Object {
      return null;
    }
  }
}
