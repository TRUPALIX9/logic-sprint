import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/constants/app_config.dart';
import '../core/constants/life_game_constants.dart';
import '../core/utils/player_name_validator.dart';
import '../models/game_model.dart';
import '../models/leaderboard_entry.dart';
import '../models/score_model.dart';
import '../repositories/score_repository.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';

class PendingAllTimeSubmission {
  const PendingAllTimeSubmission({
    required this.gameType,
    required this.score,
    required this.level,
    required this.usedSecondLife,
    required this.playerName,
  });

  final GameType gameType;
  final int score;
  final int level;
  final bool usedSecondLife;
  final String playerName;

  Map<String, dynamic> toJson() => {
    'gameType': gameType.storageKey,
    'score': score,
    'level': level,
    'usedSecondLife': usedSecondLife,
    'playerName': playerName,
  };

  factory PendingAllTimeSubmission.fromJson(Map<String, dynamic> json) {
    final key = json['gameType'] as String? ?? '';
    return PendingAllTimeSubmission(
      gameType: GameType.values.firstWhere(
        (g) => g.storageKey == key,
        orElse: () => GameType.quickMath,
      ),
      score: (json['score'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      usedSecondLife: json['usedSecondLife'] as bool? ?? false,
      playerName: json['playerName'] as String? ?? 'Player',
    );
  }
}

/// All-time leaderboard reads/writes with minimal Firebase usage.
class FirebaseLeaderboardService {
  FirebaseLeaderboardService({
    required LocalStorageService storage,
    required ScoreRepository scoreRepository,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  }) : _storage = storage,
       _scores = scoreRepository,
       _firestore = firestore,
       _connectivity = connectivity ?? Connectivity();

  final LocalStorageService _storage;
  final ScoreRepository _scores;
  final FirebaseFirestore? _firestore;
  final Connectivity _connectivity;

  FirebaseFirestore? get _db {
    if (!AppFirebaseService.isAvailable) {
      return null;
    }
    return _firestore ?? FirebaseFirestore.instance;
  }

  Future<bool> canSubmitLeaderboard() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<bool> submitAllTimeBest({
    required ScoreModel score,
    required String playerName,
  }) async {
    if (score.finalScore <= 0) {
      return false;
    }

    final validationError = PlayerNameValidator.validate(playerName);
    if (validationError != null) {
      return false;
    }

    final submittedBest = await _scores.getSubmittedAllTimeBest(score.gameType);
    if (score.finalScore <= submittedBest) {
      return false;
    }

    if (!await canSubmitLeaderboard()) {
      await queuePendingAllTimeSubmission(score, playerName: playerName);
      return false;
    }

    final uid = await AppFirebaseService.ensureAnonymousUser();
    final db = _db;
    if (uid == null || db == null) {
      await queuePendingAllTimeSubmission(score, playerName: playerName);
      return false;
    }

    try {
      final docRef = db
          .collection(AppConfig.leaderboardsRoot)
          .doc(score.gameType.leaderboardKey)
          .collection('scores')
          .doc(uid);

      await docRef.set({
        'playerId': uid,
        'playerName': PlayerNameValidator.normalize(playerName),
        'gameType': score.gameType.leaderboardKey,
        'score': score.finalScore,
        'level': score.level,
        'usedSecondLife': score.usedSecondLife,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _scores.updateSubmittedAllTimeBest(
        score.gameType,
        score.finalScore,
      );
      await _storage.setPlayerName(PlayerNameValidator.normalize(playerName));
      return true;
    } on Object {
      await queuePendingAllTimeSubmission(score, playerName: playerName);
      return false;
    }
  }

  Future<void> queuePendingAllTimeSubmission(
    ScoreModel score, {
    required String playerName,
  }) async {
    if (score.finalScore <= 0) {
      return;
    }

    final pending = await _loadPending();
    final existing = pending
        .where((p) => p.gameType == score.gameType)
        .toList();
    final current = existing.isEmpty ? 0 : existing.first.score;

    if (score.finalScore <= current) {
      return;
    }

    pending.removeWhere((p) => p.gameType == score.gameType);
    pending.add(
      PendingAllTimeSubmission(
        gameType: score.gameType,
        score: score.finalScore,
        level: score.level,
        usedSecondLife: score.usedSecondLife,
        playerName: PlayerNameValidator.normalize(playerName),
      ),
    );

    await _savePending(pending);
  }

  Future<void> syncPendingAllTimeSubmissions() async {
    if (!await canSubmitLeaderboard()) {
      return;
    }

    final pending = await _loadPending();
    if (pending.isEmpty) {
      return;
    }

    final remaining = <PendingAllTimeSubmission>[];
    for (final item in pending) {
      final submitted = await _scores.getSubmittedAllTimeBest(item.gameType);
      if (item.score <= submitted) {
        continue;
      }

      final model = ScoreModel(
        gameType: item.gameType,
        difficulty: LifeGameConstants.storageDifficulty,
        finalScore: item.score,
        bestScore: item.score,
        previousBestScore: submitted,
        correctAnswers: 0,
        wrongAnswers: 0,
        accuracyPercentage: 0,
        level: item.level,
        usedSecondLife: item.usedSecondLife,
      );

      final ok = await submitAllTimeBest(
        score: model,
        playerName: item.playerName,
      );
      if (!ok) {
        remaining.add(item);
      }
    }

    await _savePending(remaining);
  }

  Future<LeaderboardFetchResult> fetchAllTimeLeaderboard({
    required GameType gameType,
    int limit = AppConfig.leaderboardFetchLimit,
    bool forceRefresh = false,
  }) async {
    final cached = await _scores.getCachedLeaderboard(gameType);
    final fetchedToday = !_scores.shouldAutoFetchLeaderboard(gameType);

    if (!forceRefresh && fetchedToday) {
      return LeaderboardFetchResult(
        entries: cached,
        fromCache: true,
        lastFetchedDate: _scores.getLeaderboardLastFetchedDate(gameType),
      );
    }

    final db = _db;
    if (db == null) {
      return LeaderboardFetchResult(
        entries: cached,
        fromCache: true,
        lastFetchedDate: _scores.getLeaderboardLastFetchedDate(gameType),
        errorMessage: 'Online leaderboard is temporarily unavailable.',
      );
    }

    try {
      final snapshot = await db
          .collection(AppConfig.leaderboardsRoot)
          .doc(gameType.leaderboardKey)
          .collection('scores')
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      final entries = snapshot.docs
          .map((doc) => LeaderboardEntry.fromFirestore(doc.id, doc.data()))
          .toList(growable: false);

      await _scores.saveCachedLeaderboard(gameType, entries);

      return LeaderboardFetchResult(
        entries: entries,
        fromCache: false,
        lastFetchedDate: _scores.getLeaderboardLastFetchedDate(gameType),
      );
    } on Object {
      return LeaderboardFetchResult(
        entries: cached,
        fromCache: true,
        lastFetchedDate: _scores.getLeaderboardLastFetchedDate(gameType),
        errorMessage: cached.isEmpty
            ? 'Online leaderboard is temporarily unavailable.'
            : 'Showing cached scores. Could not refresh.',
      );
    }
  }

  Future<List<PendingAllTimeSubmission>> _loadPending() async {
    final raw = _storage.getPendingSubmissionsJson();
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => PendingAllTimeSubmission.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _savePending(List<PendingAllTimeSubmission> pending) async {
    final encoded = jsonEncode(pending.map((p) => p.toJson()).toList());
    await _storage.setPendingSubmissionsJson(encoded);
  }
}

class LeaderboardFetchResult {
  const LeaderboardFetchResult({
    required this.entries,
    required this.fromCache,
    this.lastFetchedDate,
    this.errorMessage,
  });

  final List<LeaderboardEntry> entries;
  final bool fromCache;
  final String? lastFetchedDate;
  final String? errorMessage;
}
