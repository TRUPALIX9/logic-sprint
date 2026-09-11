import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../models/game.dart';
import '../models/leaderboard_entry.dart';
import '../models/round_result.dart';
import '../models/run_record.dart';
import 'leaderboard_api.dart';
import 'storage.dart';

class LeaderboardLoad {
  const LeaderboardLoad(
    this.entries, {
    this.updatedAt,
    this.myRank,
    this.message,
  });

  final List<LeaderboardEntry> entries;
  final DateTime? updatedAt;

  /// The player's position on this board (null if they haven't scored).
  final int? myRank;

  /// Shown under the header: offline notice or refresh cooldown.
  final String? message;
}

/// Player profile + global Top 10.
///
/// Every finished run goes to the local History and to the server (queued
/// while offline): the server keeps one best and a play count per game and
/// difficulty. The display name is chosen once. Each board is cached for a
/// day and refetched after a new personal best; manual refresh has a 60 s
/// cooldown. Failures degrade to cached or empty data.
class Leaderboard extends ChangeNotifier {
  Leaderboard(
    this._storage, {
    required LeaderboardApi api,
    DateTime Function()? now,
  }) : _api = api,
       _now = now ?? DateTime.now;

  final Storage _storage;
  final LeaderboardApi _api;
  final DateTime Function() _now;

  String? get savedName => _storage.playerName;

  /// Server id of this player, for marking "YOU" on the boards.
  String? get playerId => _api.playerId;

  /// Local run history, newest first.
  List<RunRecord> get history => _storage.history;

  static String _boardKey(GameId game, Difficulty difficulty) =>
      '${game.name}_${difficulty.name}';

  /// Chooses (or changes) the display name. Returns null on success, or a
  /// message to show.
  Future<String?> claimName(String name) async {
    final error = PlayerName.validate(name);
    if (error != null) {
      return error;
    }
    try {
      await _api.claimName(name.trim());
    } on NameTakenException {
      return 'That name is taken — try another.';
    } on Object {
      return 'Couldn’t reach the server. Check your connection and try again.';
    }
    await _storage.setPlayerName(name.trim());
    // Boards cached before the name was set don't show it yet.
    await _storage.setLeaderboardCache('{}');
    notifyListeners();
    return null;
  }

  /// Saves a finished run to History and sends it to the server (or queues
  /// it until the next successful sync). Completes with true once synced.
  Future<bool> recordRun(RoundResult result) async {
    final run = RunRecord.fromResult(result, _now());
    await _storage.addHistory(run);
    await _storage.setPendingRuns([..._storage.pendingRuns, run]);
    notifyListeners();
    if (result.isNewBest) {
      await _store(_boardKey(result.game, result.difficulty), null);
    }
    return syncPending();
  }

  // Syncs run one after another, so no queued run is ever sent twice.
  Future<bool> _sync = Future.value(true);

  /// Sends queued runs in order; stops at the first failure and keeps the
  /// rest for next time. Returns true when the queue is empty.
  Future<bool> syncPending() => _sync = _sync.then((_) => _drain());

  Future<bool> _drain() async {
    final pending = _storage.pendingRuns;
    var sent = 0;
    try {
      for (final run in pending) {
        await _api.recordRun(run.game, run.difficulty, run.score, run.duration);
        sent++;
      }
    } on Object {
      // Offline: retried on the next run or app start.
    }
    if (sent > 0) {
      await _storage.setPendingRuns(pending.sublist(sent));
    }
    return sent == pending.length;
  }

  /// All cached boards: key → {"at": epoch ms, "rank": int?, "rows": [...]}.
  Map<String, dynamic> _boards() {
    final raw = _storage.leaderboardCache;
    if (raw == null) {
      return {};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      return {};
    }
  }

  LeaderboardLoad? _cached(String key) {
    try {
      final board = _boards()[key] as Map?;
      if (board == null) {
        return null;
      }
      return LeaderboardLoad(
        (board['rows'] as List)
            .map(
              (row) => LeaderboardEntry.fromRow(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .nonNulls
            .toList(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(board['at'] as int),
        myRank: (board['rank'] as num?)?.toInt(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _store(String key, LeaderboardLoad? load) async {
    final boards = _boards();
    if (load == null) {
      boards.remove(key);
    } else {
      boards[key] = {
        'at': load.updatedAt!.millisecondsSinceEpoch,
        'rank': load.myRank,
        'rows': load.entries.map((e) => e.toRow()).toList(),
      };
    }
    await _storage.setLeaderboardCache(jsonEncode(boards));
  }

  Future<LeaderboardLoad> load(
    GameId game,
    Difficulty difficulty, {
    bool refresh = false,
  }) async {
    final key = _boardKey(game, difficulty);
    final cached = _cached(key);
    final fresh =
        cached != null &&
        _now().difference(cached.updatedAt!) < AppConfig.leaderboardCacheTtl;

    if (!refresh && fresh) {
      return cached;
    }

    if (refresh) {
      final last = _storage.lastLeaderboardRefresh;
      final wait = last == null
          ? Duration.zero
          : AppConfig.leaderboardRefreshCooldown - _now().difference(last);
      if (wait > Duration.zero) {
        return LeaderboardLoad(
          cached?.entries ?? const [],
          updatedAt: cached?.updatedAt,
          myRank: cached?.myRank,
          message: 'Refresh available in ${wait.inSeconds + 1}s',
        );
      }
      await _storage.setLastLeaderboardRefresh(_now());
    }

    try {
      // Queued runs first, so the board and rank include them.
      await syncPending();
      final entries = (await _api.top(game, difficulty))
          .map(LeaderboardEntry.fromRow)
          .nonNulls
          .where((e) => e.game == game && e.difficulty == difficulty)
          .toList();
      final load = LeaderboardLoad(
        entries,
        updatedAt: _now(),
        myRank: await _api.myRank(game, difficulty),
      );
      await _store(key, load);
      return load;
    } on Object {
      return LeaderboardLoad(
        cached?.entries ?? const [],
        updatedAt: cached?.updatedAt,
        myRank: cached?.myRank,
        message: cached == null
            ? 'Leaderboard is offline right now.'
            : 'Offline — showing saved scores.',
      );
    }
  }
}
