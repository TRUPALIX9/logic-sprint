import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/game.dart';

/// The server refused a display name because another player has it.
class NameTakenException implements Exception {
  const NameTakenException();
}

/// Server side of player profiles and the Top 10: Supabase in the app, a
/// fake in tests. Any call may throw when offline.
abstract interface class LeaderboardApi {
  /// The signed-in player's id, or null before the first sign-in.
  String? get playerId;

  /// Signs this device in anonymously if it isn't yet (no login screen).
  Future<void> signIn();

  /// Sets the display name. Throws [NameTakenException] if it's in use.
  Future<void> claimName(String name);

  /// Records one finished run: +1 play, and the best if this run beats it.
  Future<void> recordRun(
    GameId game,
    Difficulty difficulty,
    int score,
    Duration duration,
  );

  /// Top 10 rows for one board (see the `leaderboard_top` view).
  Future<List<Map<String, dynamic>>> top(GameId game, Difficulty difficulty);

  /// The caller's position on one board, or null if they haven't scored.
  Future<int?> myRank(GameId game, Difficulty difficulty);
}

/// [LeaderboardApi] backed by supabase/schema.sql.
class SupabaseLeaderboardApi implements LeaderboardApi {
  /// The Supabase client has no timeout of its own; without one a dead
  /// network leaves spinners up forever.
  static const _timeout = Duration(seconds: 8);

  static bool _ready = false;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
      );
      _ready = true;
    } on Object {
      _ready = false;
    }
  }

  SupabaseClient get _client {
    if (!_ready) {
      throw StateError('Supabase unavailable');
    }
    return Supabase.instance.client;
  }

  @override
  String? get playerId =>
      _ready ? Supabase.instance.client.auth.currentUser?.id : null;

  @override
  Future<void> signIn() async {
    if (_client.auth.currentUser == null) {
      await _client.auth.signInAnonymously().timeout(_timeout);
    }
  }

  @override
  Future<void> claimName(String name) async {
    await signIn();
    try {
      await _client
          .rpc('claim_name', params: {'p_name': name})
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      if (e.message.contains('name_taken')) {
        throw const NameTakenException();
      }
      rethrow;
    }
  }

  @override
  Future<void> recordRun(
    GameId game,
    Difficulty difficulty,
    int score,
    Duration duration,
  ) async {
    await signIn();
    await _client
        .rpc(
          'record_run',
          params: {
            'p_game': game.name,
            'p_difficulty': difficulty.name,
            'p_score': score,
            'p_duration_ms': game.tracksTime ? duration.inMilliseconds : null,
          },
        )
        .timeout(_timeout);
  }

  @override
  Future<List<Map<String, dynamic>>> top(
    GameId game,
    Difficulty difficulty,
  ) async {
    final rows = await _client
        .from('leaderboard_top')
        .select(
          'player_id, player_name, game_type, difficulty, score, duration_ms, best_at',
        )
        .eq('game_type', game.name)
        .eq('difficulty', difficulty.name)
        .order('score', ascending: false)
        .order('tie_key', ascending: true, nullsFirst: false)
        .limit(AppConfig.leaderboardLimit)
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<int?> myRank(GameId game, Difficulty difficulty) async {
    if (_client.auth.currentUser == null) {
      return null;
    }
    final rank = await _client
        .rpc(
          'my_rank',
          params: {'p_game': game.name, 'p_difficulty': difficulty.name},
        )
        .timeout(_timeout);
    return (rank as num?)?.toInt();
  }
}
