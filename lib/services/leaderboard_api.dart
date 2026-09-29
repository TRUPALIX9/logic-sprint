import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/game.dart';

/// The server refused a name + tag because another player has it.
class NameTakenException implements Exception {
  const NameTakenException();
}

/// The server refused a name because it contains a banned word.
class NameNotAllowedException implements Exception {
  const NameNotAllowedException();
}

/// Every board's Top 10 in one go, plus the caller's rank on each board
/// they've scored on (keyed `<game>_<difficulty>`).
typedef Boards = ({List<Map<String, dynamic>> rows, Map<String, int> myRanks});

/// Server side of player profiles and the Top 10: Supabase in the app, a
/// fake in tests. Any call may throw when offline.
abstract interface class LeaderboardApi {
  /// The signed-in player's id, or null before the first sign-in.
  String? get playerId;

  /// Signs this device in anonymously if it isn't yet (no login screen).
  Future<void> signIn();

  /// Sets the display name and its 4-digit [tag]. Throws
  /// [NameTakenException] if another player has that name + tag, and
  /// [NameNotAllowedException] if the name contains a banned word.
  Future<void> claimName(String name, int tag);

  /// A random tag no one else uses with [name], or null if none is left.
  Future<int?> freeTag(String name);

  /// This player's tag on the server (null if they have no name yet).
  Future<int?> myTag();

  /// Records one finished run: +1 play, and the best if this run beats it.
  Future<void> recordRun(
    GameId game,
    Difficulty difficulty,
    int score,
    Duration duration,
  );

  /// Top 10 rows for every board (see the `leaderboard_ranked` view) and
  /// the caller's ranks.
  Future<Boards> boards();

  /// Reports another player's name as offensive.
  Future<void> reportName(String playerId);

  /// Deletes this player's server account (name, bests, reports) and signs
  /// out; the next [signIn] starts a new player.
  Future<void> deleteMyData();
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
  Future<void> claimName(String name, int tag) async {
    await signIn();
    try {
      await _client
          .rpc('claim_name', params: {'p_name': name, 'p_tag': tag})
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      if (e.message.contains('name_taken')) {
        throw const NameTakenException();
      }
      if (e.message.contains('name_not_allowed')) {
        throw const NameNotAllowedException();
      }
      if (e.message.contains('invalid_tag') ||
          e.message.contains('invalid_name')) {
        throw ArgumentError(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<int?> freeTag(String name) async {
    await signIn();
    final tag = await _client
        .rpc('free_tag', params: {'p_name': name})
        .timeout(_timeout);
    return (tag as num?)?.toInt();
  }

  @override
  Future<int?> myTag() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) {
      return null;
    }
    final row = await _client
        .from('profiles')
        .select('tag')
        .eq('id', me)
        .maybeSingle()
        .timeout(_timeout);
    return (row?['tag'] as num?)?.toInt();
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
  Future<void> reportName(String playerId) async {
    await signIn();
    await _client
        .rpc('report_name', params: {'p_player': playerId})
        .timeout(_timeout);
  }

  @override
  Future<void> deleteMyData() async {
    if (_client.auth.currentUser == null) {
      return;
    }
    await _client.rpc('delete_my_data').timeout(_timeout);
    // The user is gone on the server; just drop the local session.
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  @override
  Future<Boards> boards() async {
    final rows = await _client
        .from('leaderboard_ranked')
        .select(
          'player_id, player_name, game_type, difficulty, score, duration_ms, best_at, board_rank',
        )
        .lte('board_rank', AppConfig.leaderboardLimit)
        .order('board_rank', ascending: true)
        .order('tie_key', ascending: true, nullsFirst: false)
        .timeout(_timeout);
    final me = _client.auth.currentUser?.id;
    final mine = me == null
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('leaderboard_ranked')
              .select('game_type, difficulty, board_rank')
              .eq('player_id', me)
              .timeout(_timeout);
    return (
      rows: List<Map<String, dynamic>>.from(rows),
      myRanks: {
        for (final row in mine)
          '${row['game_type']}_${row['difficulty']}': (row['board_rank'] as num)
              .toInt(),
      },
    );
  }
}
