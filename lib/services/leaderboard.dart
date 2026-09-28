import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
/// difficulty. The display name carries a 4-digit tag ("NEON_FOX#0420"), so
/// names needn't be unique; only name + tag is.
///
/// Boards change once a day for everyone: the first look after 00:00 UTC
/// fetches every board in one go; until the next 00:00 UTC the cache is
/// served. "Refresh ▶" (after a rewarded interstitial) fetches early, then
/// waits [AppConfig.leaderboardRefreshCooldown]. A new personal best
/// updates the player's own cached board straight away (and goes to the
/// server); other players see it after the next reset. Failures degrade to
/// cached or empty data.
///
/// Cache (`Storage.leaderboardCache`), one JSON object:
/// ```
/// {
///   "_fetchedAt": epoch ms of the last daily fetch,
///   "<game>_<difficulty>": {
///     "at": epoch ms the board last changed (fetch or a local best),
///     "rank": int | null,           // the player's rank
///     "rows": [view rows],          // LeaderboardEntry.toRow()
///     "prev": {"rank": int | null, "rows": [...]},  // before the last change
///     "anim": true                  // optional: changed, not yet shown
///   }
/// }
/// ```
class Leaderboard extends ChangeNotifier {
  Leaderboard(
    this._storage, {
    required LeaderboardApi api,
    DateTime Function()? now,
    Random? random,
  }) : _api = api,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  final Storage _storage;
  final LeaderboardApi _api;
  final DateTime Function() _now;
  final Random _random;

  static const _fetchedKey = '_fetchedAt';

  /// The name without its tag.
  String? get savedName => _storage.playerName;

  /// The 4-digit tag, once known.
  int? get savedTag => _storage.playerTag;

  /// "NEON_FOX#0420" (just the name until the tag is known).
  String? get displayName {
    final name = savedName;
    final tag = savedTag;
    return name == null || tag == null ? name : '$name#${formatTag(tag)}';
  }

  /// Server id of this player, for marking "YOU" on the boards.
  String? get playerId => _api.playerId;

  /// Local run history, newest first.
  List<RunRecord> get history => _storage.history;

  /// The clock used for freshness.
  DateTime now() => _now();

  static String formatTag(int tag) => '$tag'.padLeft(4, '0');

  /// The most recent 00:00 UTC at or before [now].
  static DateTime lastReset(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  /// The next 00:00 UTC after [now]: when the boards update again.
  static DateTime nextReset(DateTime now) =>
      lastReset(now).add(const Duration(days: 1));

  /// When every board was last fetched from the server.
  DateTime? get fetchedAt {
    final at = _cache()[_fetchedKey];
    return at is num ? DateTime.fromMillisecondsSinceEpoch(at.toInt()) : null;
  }

  /// True when the boards are from before the latest 00:00 UTC.
  bool get due {
    final at = fetchedAt;
    return at == null || at.isBefore(lastReset(_now()));
  }

  static String _boardKey(GameId game, Difficulty difficulty) =>
      '${game.name}_${difficulty.name}';

  /// How long until "Refresh ▶" is allowed again (zero when it is).
  Duration refreshWait() {
    final last = _storage.lastLeaderboardRefresh;
    if (last == null) {
      return Duration.zero;
    }
    const cooldown = AppConfig.leaderboardRefreshCooldown;
    final wait = cooldown - _now().difference(last);
    // Clamped: a clock set backwards mustn't lock refresh for longer.
    return wait <= Duration.zero
        ? Duration.zero
        : (wait > cooldown ? cooldown : wait);
  }

  /// A free tag for [name] (from the server; random when offline).
  Future<int> suggestTag(String name) async {
    try {
      final tag = await _api.freeTag(name.trim());
      if (tag != null) {
        return tag;
      }
    } on Object {
      // Offline: any tag; the server still checks it on save.
    }
    return _random.nextInt(10000);
  }

  /// Chooses (or changes) the display name and its [tag]. Returns null on
  /// success, or a message to show.
  Future<String?> claimName(String name, int tag) async {
    final error = PlayerName.validate(name);
    if (error != null) {
      return error;
    }
    if (tag < 0 || tag > 9999) {
      return 'Pick a 4-digit code.';
    }
    final trimmed = name.trim();
    try {
      await _api.claimName(trimmed, tag);
    } on NameTakenException {
      return '$trimmed#${formatTag(tag)} is taken — try another code.';
    } on ArgumentError {
      return 'Pick a 4-digit code.';
    } on Object {
      return 'Couldn’t reach the server. Check your connection and try again.';
    }
    await _storage.setPlayerName(trimmed);
    await _storage.setPlayerTag(tag);
    await _renameMe();
    // Unnamed players aren't on the server's boards: fetch again on the next
    // look so the new name shows up with its rank (free; not the cooldown).
    await _write(_cache()..remove(_fetchedKey));
    notifyListeners();
    return null;
  }

  /// Players named before tags existed: learn the tag the server gave them.
  Future<void> _syncTag() async {
    if (savedName == null || savedTag != null) {
      return;
    }
    try {
      final tag = await _api.myTag();
      if (tag != null) {
        await _storage.setPlayerTag(tag);
        await _renameMe();
        notifyListeners();
      }
    } on Object {
      // Next time.
    }
  }

  /// Saves a finished run to History and sends it to the server (or queues
  /// it until the next successful sync). A new best also moves the player
  /// on their own cached board right away. Completes with true once synced.
  Future<bool> recordRun(RoundResult result) async {
    final run = RunRecord.fromResult(result, _now());
    await _storage.addHistory(run);
    await _storage.setPendingRuns([..._storage.pendingRuns, run]);
    if (result.isNewBest) {
      await _applyLocalBest(result);
    }
    notifyListeners();
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

  static List<Map<String, dynamic>> _toRows(List<LeaderboardEntry> entries) => [
    for (final e in entries) e.toRow(),
  ];

  /// The cached board, and whether it changed since it was last shown.
  static (LeaderboardLoad, bool)? _parse(Object? raw) {
    try {
      final board = raw as Map?;
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
      return (load, board['anim'] == true);
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> _board(
    DateTime at,
    List<LeaderboardEntry> entries,
    int? myRank, {
    List<LeaderboardEntry>? previous,
    int? previousMyRank,
    bool anim = false,
  }) => {
    'at': at.millisecondsSinceEpoch,
    'rank': myRank,
    'rows': _toRows(entries),
    if (previous != null)
      'prev': {'rank': previousMyRank, 'rows': _toRows(previous)},
    if (anim) 'anim': true,
  };

  /// Every board this build shows.
  static Iterable<(GameId, Difficulty)> get _allBoards sync* {
    for (final game in GameId.values) {
      if (game.hasDifficulty) {
        for (final difficulty in Difficulty.values) {
          yield (game, difficulty);
        }
      } else {
        yield (game, GameId.rampDifficulty);
      }
    }
  }

  // One daily fetch at a time, shared by every board asking for it.
  Future<void>? _fetching;

  Future<void> _fetchAll() =>
      _fetching ??= _doFetchAll().whenComplete(() => _fetching = null);

  Future<void> _doFetchAll() async {
    // Queued runs first, so the boards and ranks include them.
    await syncPending();
    final boards = await _api.boards();
    final byBoard = <String, List<LeaderboardEntry>>{};
    for (final row in boards.rows) {
      final entry = LeaderboardEntry.fromRow(row);
      if (entry != null) {
        (byBoard[_boardKey(entry.game, entry.difficulty)] ??= []).add(entry);
      }
    }
    final at = _now();
    final cache = _cache();
    for (final (game, difficulty) in _allBoards) {
      final key = _boardKey(game, difficulty);
      final entries = (byBoard[key] ?? const <LeaderboardEntry>[])
          .take(AppConfig.leaderboardLimit)
          .toList();
      final myRank = boards.myRanks[key];
      final cached = _parse(cache[key]);
      final old = cached?.$1;
      final changed =
          old == null ||
          old.myRank != myRank ||
          !sameStandings(old.entries, entries);
      // What the player saw last becomes "before"; an unchanged board
      // keeps the older snapshot (and its movement chips).
      cache[key] = _board(
        at,
        entries,
        myRank,
        previous: changed ? old?.entries : old.previous,
        previousMyRank: changed ? old?.myRank : old.previousMyRank,
        anim: changed || (cached?.$2 ?? false),
      );
    }
    cache[_fetchedKey] = at.millisecondsSinceEpoch;
    await _write(cache);
    notifyListeners();
  }

  /// Puts a new personal best on the player's cached board (other players'
  /// devices get it after the next 00:00 UTC).
  Future<void> _applyLocalBest(RoundResult result) async {
    final me = playerId;
    final name = displayName;
    if (me == null || name == null) {
      return;
    }
    final key = _boardKey(result.game, result.difficulty);
    final cache = _cache();
    final board = _parse(cache[key])?.$1;
    if (board == null) {
      return;
    }
    final mine = LeaderboardEntry(
      playerId: me,
      playerName: name,
      score: result.score,
      game: result.game,
      difficulty: result.difficulty,
      duration: result.game.tracksTime ? result.duration : null,
      bestAt: _now(),
    );
    final old = board.entries.where((e) => e.playerId == me).firstOrNull;
    if (old != null && old.score >= mine.score) {
      return;
    }
    final others = board.entries.where((e) => e.playerId != me).toList();
    // Others keep their order; the new best goes above everyone it beats
    // (an equal score only wins on a shorter time in timed games).
    var at = others.indexWhere(
      (e) =>
          mine.score > e.score ||
          (mine.score == e.score &&
              result.game.tracksTime &&
              e.duration != null &&
              result.duration < e.duration!),
    );
    if (at < 0) {
      at = others.length;
    }
    final entries = [...others]..insert(at, mine);
    final top = entries.take(AppConfig.leaderboardLimit).toList();
    final inTop = top.any((e) => e.playerId == me);
    // Outside the Top 10 the exact rank is only known after the reset.
    final myRank = inTop ? at + 1 : board.myRank;
    cache[key] = _board(
      _now(),
      top,
      myRank,
      previous: board.entries,
      previousMyRank: board.myRank,
      anim: true,
    );
    await _write(cache);
  }

  /// After a name change, shows the new name on the player's cached rows.
  Future<void> _renameMe() async {
    final me = playerId;
    final name = displayName;
    if (me == null || name == null) {
      return;
    }
    final cache = _cache();
    for (final MapEntry(:key, :value) in cache.entries.toList()) {
      final parsed = _parse(value);
      if (parsed == null) {
        continue;
      }
      final (load, anim) = parsed;
      List<LeaderboardEntry> rename(List<LeaderboardEntry> rows) => [
        for (final e in rows) e.playerId == me ? e.withName(name) : e,
      ];
      final previous = load.previous;
      cache[key] = _board(
        load.updatedAt!,
        rename(load.entries),
        load.myRank,
        previous: previous == null ? null : rename(previous),
        previousMyRank: load.previousMyRank,
        anim: anim,
      );
    }
    await _write(cache);
  }

  static LeaderboardLoad _savedLoad(LeaderboardLoad? cached, String message) =>
      cached?._withMessage(message) ?? LeaderboardLoad([], message: message);

  /// One board. The first look after 00:00 UTC fetches every board at once;
  /// otherwise the cache is served. [refresh] ("Refresh ▶", after its ad)
  /// fetches every board now unless the cooldown is still running. A board
  /// that changed since it was last shown comes back with
  /// [LeaderboardLoad.changed] set (once). When [offline] (no network
  /// connection) the cache is served without trying the server.
  Future<LeaderboardLoad> load(
    GameId game,
    Difficulty difficulty, {
    bool offline = false,
    bool refresh = false,
  }) async {
    final key = _boardKey(game, difficulty);
    if (offline) {
      return _savedLoad(
        _parse(_cache()[key])?.$1,
        'Offline — showing saved scores.',
      );
    }
    unawaited(_syncTag());
    final manual = refresh && refreshWait() == Duration.zero;
    if (due || manual) {
      try {
        await _fetchAll();
        // Only a refresh that worked starts the cooldown.
        if (manual) {
          await _storage.setLastLeaderboardRefresh(_now());
        }
      } on Object {
        return _savedLoad(
          _parse(_cache()[key])?.$1,
          'Leaderboard is offline right now.',
        );
      }
    }
    final cache = _cache();
    final parsed = _parse(cache[key]);
    if (parsed == null) {
      return LeaderboardLoad(const [], updatedAt: fetchedAt);
    }
    final (load, anim) = parsed;
    if (!anim) {
      return load;
    }
    // Shown once as a change; after that it's the settled board.
    (cache[key] as Map).remove('anim');
    await _write(cache);
    return LeaderboardLoad(
      load.entries,
      updatedAt: load.updatedAt,
      myRank: load.myRank,
      previous: load.previous,
      previousMyRank: load.previousMyRank,
      changed: true,
    );
  }
}
