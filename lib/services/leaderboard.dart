import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/format.dart';
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
    this.previous,
    this.previousMyRank,
    this.changed = false,
  });

  final List<LeaderboardEntry> entries;
  final DateTime? updatedAt;

  /// The player's position on this board (null if they haven't scored).
  final int? myRank;

  /// Shown under the header: offline notice or refresh cooldown.
  final String? message;

  /// The board as it stood before its last change; null until this board
  /// has changed at least once since the player first saw it.
  final List<LeaderboardEntry>? previous;

  /// The player's position in [previous].
  final int? previousMyRank;

  /// True when this load just came from the server and differs from what the
  /// player saw before (or is their first look at the board). The Ranks tab
  /// only animates these; cached loads show the final state.
  final bool changed;

  /// Movement since [previous] by player id (empty on a first view).
  Map<String, RankMove> get moves {
    final previous = this.previous;
    return previous == null ? const {} : rankMoves(previous, entries);
  }

  LeaderboardLoad _withMessage(String message) => LeaderboardLoad(
    entries,
    updatedAt: updatedAt,
    myRank: myRank,
    previous: previous,
    previousMyRank: previousMyRank,
    message: message,
  );
}

/// Player profile + global Top 10.
///
/// Every finished run goes to the local History and to the server (queued
/// while offline): the server keeps one best and a play count per game and
/// difficulty. The display name is chosen once. Each board is fetched on the
/// first look of each local calendar day and again after a new personal
/// best; otherwise the cache is served. "Refresh now" waits
/// [AppConfig.leaderboardRefreshCooldown] after a rewarded refresh, or
/// [AppConfig.leaderboardFreeRefreshCooldown] after a free one. Failures
/// degrade to cached or empty data.
///
/// Cache (`Storage.leaderboardCache`), one JSON object:
/// ```
/// {
///   "<game>_<difficulty>": {
///     "at": epoch ms of the fetch,
///     "rank": int | null,           // the player's rank
///     "rows": [view rows],          // LeaderboardEntry.toRow()
///     "prev": {"rank": int | null, "rows": [...]},  // before the last change
///     "stale": true                 // optional: refetch on next look
///   },
///   "_refresh": {"free": bool}      // kind of the last manual refresh
/// }
/// ```
/// The time of the last manual refresh is `Storage.lastLeaderboardRefresh`.
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

  static const _refreshKey = '_refresh';

  String? get savedName => _storage.playerName;

  /// Server id of this player, for marking "YOU" on the boards.
  String? get playerId => _api.playerId;

  /// Local run history, newest first.
  List<RunRecord> get history => _storage.history;

  /// The clock used for freshness and cooldowns.
  DateTime now() => _now();

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
    await _markStale((_) => true);
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
      final key = _boardKey(result.game, result.difficulty);
      await _markStale((k) => k == key);
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

  /// How long until "Refresh now" is allowed again (zero when it is).
  Duration refreshWait() {
    final last = _storage.lastLeaderboardRefresh;
    if (last == null) {
      return Duration.zero;
    }
    final meta = _cache()[_refreshKey];
    final cooldown = meta is Map && meta['free'] == true
        ? AppConfig.leaderboardFreeRefreshCooldown
        : AppConfig.leaderboardRefreshCooldown;
    final wait = cooldown - _now().difference(last);
    // Clamped: a clock set backwards mustn't lock refresh for longer.
    return wait <= Duration.zero
        ? Duration.zero
        : (wait > cooldown ? cooldown : wait);
  }

  /// The whole cache object (see the class doc).
  Map<String, dynamic> _cache() {
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

  Future<void> _write(Map<String, dynamic> cache) =>
      _storage.setLeaderboardCache(jsonEncode(cache));

  static List<LeaderboardEntry> _rows(Object? rows) => (rows as List)
      .map(
        (row) =>
            LeaderboardEntry.fromRow(Map<String, dynamic>.from(row as Map)),
      )
      .nonNulls
      .toList();

  /// The cached board and whether it's marked stale.
  (LeaderboardLoad, bool)? _cached(String key) {
    try {
      final board = _cache()[key] as Map?;
      if (board == null) {
        return null;
      }
      final prev = board['prev'] as Map?;
      final load = LeaderboardLoad(
        _rows(board['rows']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (board['at'] as num).toInt(),
        ),
        myRank: (board['rank'] as num?)?.toInt(),
        previous: prev == null ? null : _rows(prev['rows']),
        previousMyRank: (prev?['rank'] as num?)?.toInt(),
      );
      return (load, board['stale'] == true);
    } on Object {
      return null;
    }
  }

  Future<void> _save(String key, LeaderboardLoad load) async {
    final cache = _cache();
    final previous = load.previous;
    cache[key] = {
      'at': load.updatedAt!.millisecondsSinceEpoch,
      'rank': load.myRank,
      'rows': [for (final e in load.entries) e.toRow()],
      if (previous != null)
        'prev': {
          'rank': load.previousMyRank,
          'rows': [for (final e in previous) e.toRow()],
        },
    };
    await _write(cache);
  }

  /// Forces a refetch of matching boards while keeping their rows as the
  /// "before" snapshot, so the change still animates.
  Future<void> _markStale(bool Function(String key) which) async {
    final cache = _cache();
    for (final MapEntry(:key, :value) in cache.entries) {
      if (key != _refreshKey && value is Map && which(key)) {
        value['stale'] = true;
      }
    }
    await _write(cache);
  }

  static LeaderboardLoad _offlineLoad(LeaderboardLoad? cached) =>
      cached?._withMessage('Offline — showing saved scores.') ??
      const LeaderboardLoad([], message: 'Leaderboard is offline right now.');

  /// One board. Served from the cache if it was fetched today (local time)
  /// and isn't stale; [refresh] ("Refresh now") always fetches, subject to
  /// the cooldown for a [rewarded] or free refresh. When [offline] (no
  /// network connection) the cache is served without trying the server.
  Future<LeaderboardLoad> load(
    GameId game,
    Difficulty difficulty, {
    bool refresh = false,
    bool rewarded = false,
    bool offline = false,
  }) async {
    final key = _boardKey(game, difficulty);
    final (cached, stale) = _cached(key) ?? (null, true);
    if (offline) {
      return _offlineLoad(cached);
    }
    final fresh =
        cached != null &&
        !stale &&
        calendarDaysBetween(cached.updatedAt!, _now()) == 0;

    if (!refresh && fresh) {
      return cached;
    }

    if (refresh) {
      final wait = refreshWait();
      if (wait > Duration.zero) {
        final message =
            'Refresh available in ${(wait.inMilliseconds / 1000).ceil()}s';
        return cached?._withMessage(message) ??
            LeaderboardLoad(const [], message: message);
      }
      await _storage.setLastLeaderboardRefresh(_now());
      await _write(_cache()..[_refreshKey] = {'free': !rewarded});
    }

    try {
      // Queued runs first, so the board and rank include them.
      await syncPending();
      final entries = (await _api.top(game, difficulty))
          .map(LeaderboardEntry.fromRow)
          .nonNulls
          .where((e) => e.game == game && e.difficulty == difficulty)
          .toList();
      final myRank = await _api.myRank(game, difficulty);
      final changed =
          cached == null ||
          cached.myRank != myRank ||
          !sameStandings(cached.entries, entries);
      final load = LeaderboardLoad(
        entries,
        updatedAt: _now(),
        myRank: myRank,
        // What the player saw last becomes "before"; an unchanged board
        // keeps the older snapshot (and its movement chips).
        previous: changed ? cached?.entries : cached.previous,
        previousMyRank: changed ? cached?.myRank : cached.previousMyRank,
        changed: changed,
      );
      await _save(key, load);
      return load;
    } on Object {
      return _offlineLoad(cached);
    }
  }
}
