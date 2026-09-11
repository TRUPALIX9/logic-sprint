import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/game.dart';
import '../models/leaderboard_entry.dart';
import 'storage.dart';

class LeaderboardLoad {
  const LeaderboardLoad(this.entries, {this.updatedAt, this.message});

  final List<LeaderboardEntry> entries;
  final DateTime? updatedAt;

  /// Shown under the header: offline notice or refresh cooldown.
  final String? message;
}

typedef FetchTop =
    Future<List<Map<String, dynamic>>> Function(
      GameId game,
      Difficulty difficulty,
    );
typedef InsertScore = Future<void> Function(Map<String, dynamic> row);

/// One global Top 10 per game (and per difficulty where the game has them).
/// Each board is cached for 10 minutes; manual refresh has a 60 s cooldown;
/// posting is limited to 5 a day. Failures degrade to cached or empty data.
class Leaderboard {
  Leaderboard(
    this._storage, {
    required this.appVersion,
    FetchTop? fetchTop,
    InsertScore? insert,
    DateTime Function()? now,
  }) : _fetchTop = fetchTop ?? _supabaseFetch,
       _insert = insert ?? _supabaseInsert,
       _now = now ?? DateTime.now;

  final Storage _storage;
  final String appVersion;
  final FetchTop _fetchTop;
  final InsertScore _insert;
  final DateTime Function() _now;

  static bool supabaseReady = false;

  static Future<void> initSupabase() async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
      );
      supabaseReady = true;
    } on Object {
      supabaseReady = false;
    }
  }

  static Future<List<Map<String, dynamic>>> _supabaseFetch(
    GameId game,
    Difficulty difficulty,
  ) async {
    if (!supabaseReady) {
      throw StateError('Supabase unavailable');
    }
    final rows = await Supabase.instance.client
        .from(AppConfig.leaderboardTable)
        .select('id, player_name, score, game_type, difficulty, created_at')
        .eq('game_type', game.name)
        .eq('difficulty', difficulty.name)
        .order('score', ascending: false)
        .limit(AppConfig.leaderboardLimit)
        .timeout(_requestTimeout);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> _supabaseInsert(Map<String, dynamic> row) async {
    if (!supabaseReady) {
      throw StateError('Supabase unavailable');
    }
    await Supabase.instance.client
        .from(AppConfig.leaderboardTable)
        .insert(row)
        .timeout(_requestTimeout);
  }

  /// The Supabase client has no timeout of its own; without one a dead
  /// network leaves the Ranks spinner up forever.
  static const _requestTimeout = Duration(seconds: 8);

  static String _boardKey(GameId game, Difficulty difficulty) =>
      '${game.name}_${difficulty.name}';

  String get _today {
    final d = _now();
    return '${d.year}-${d.month}-${d.day}';
  }

  int get postsLeftToday =>
      AppConfig.maxDailySubmissions - _storage.submissionsOn(_today);

  String? get savedName => _storage.playerName;

  /// All cached boards: key → {"at": epoch ms, "rows": [...]}.
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

  (List<LeaderboardEntry>, DateTime)? _cached(String key) {
    try {
      final board = _boards()[key] as Map?;
      if (board == null) {
        return null;
      }
      final entries = (board['rows'] as List)
          .map(
            (row) =>
                LeaderboardEntry.fromRow(Map<String, dynamic>.from(row as Map)),
          )
          .nonNulls
          .toList();
      return (entries, DateTime.fromMillisecondsSinceEpoch(board['at'] as int));
    } on Object {
      return null;
    }
  }

  Future<void> _store(String key, List<LeaderboardEntry>? entries) async {
    final boards = _boards();
    if (entries == null) {
      boards.remove(key);
    } else {
      boards[key] = {
        'at': _now().millisecondsSinceEpoch,
        'rows': entries.map((e) => e.toRow()).toList(),
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
        _now().difference(cached.$2) < AppConfig.leaderboardCacheTtl;

    if (!refresh && fresh) {
      return LeaderboardLoad(cached.$1, updatedAt: cached.$2);
    }

    if (refresh) {
      final last = _storage.lastLeaderboardRefresh;
      final wait = last == null
          ? Duration.zero
          : AppConfig.leaderboardRefreshCooldown - _now().difference(last);
      if (wait > Duration.zero) {
        return LeaderboardLoad(
          cached?.$1 ?? const [],
          updatedAt: cached?.$2,
          message: 'Refresh available in ${wait.inSeconds + 1}s',
        );
      }
      await _storage.setLastLeaderboardRefresh(_now());
    }

    try {
      final entries = (await _fetchTop(game, difficulty))
          .map(LeaderboardEntry.fromRow)
          .nonNulls
          .where((e) => e.game == game && e.difficulty == difficulty)
          .toList();
      await _store(key, entries);
      return LeaderboardLoad(entries, updatedAt: _now());
    } on Object {
      return LeaderboardLoad(
        cached?.$1 ?? const [],
        updatedAt: cached?.$2,
        message: cached == null
            ? 'Leaderboard is offline right now.'
            : 'Offline — showing saved scores.',
      );
    }
  }

  /// Posts a score. Returns null on success, or a message to show.
  Future<String?> submit({
    required String name,
    required GameId game,
    required Difficulty difficulty,
    required int score,
  }) async {
    final error = PlayerName.validate(name);
    if (error != null) {
      return error;
    }
    if (score <= 0) {
      return 'Score something first!';
    }
    if (postsLeftToday <= 0) {
      return 'Daily post limit reached. Try again tomorrow.';
    }
    try {
      await _insert({
        'player_name': name.trim(),
        'score': score,
        'game_type': game.name,
        'difficulty': difficulty.name,
        'app_version': appVersion,
      });
    } on Object {
      return 'Couldn’t reach the leaderboard. Your best is saved on this device.';
    }
    await _storage.recordSubmission(_today);
    await _storage.setPlayerName(name.trim());
    // Drop this board's cache so the new score shows on the next load.
    await _store(_boardKey(game, difficulty), null);
    return null;
  }
}
