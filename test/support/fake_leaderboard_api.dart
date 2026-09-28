import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/services/leaderboard_api.dart';

/// In-memory [LeaderboardApi] for tests. Flip [online] to simulate outages.
class FakeLeaderboardApi implements LeaderboardApi {
  FakeLeaderboardApi({this.rows = const [], this.rank});

  /// Rows served by [boards] (any boards, already in order).
  List<Map<String, dynamic>> rows;

  /// The player's rank on every board that has rows.
  int? rank;
  bool online = true;
  String? name;
  int? tag;

  /// Taken "name#tag" pairs, lower case ("axon#0001").
  final taken = <String>{};

  /// What [freeTag] answers.
  int? free = 1234;
  final runs = <(GameId, Difficulty, int, Duration)>[];

  /// How many times [boards] was called.
  int fetches = 0;

  void _check() {
    if (!online) {
      throw StateError('offline');
    }
  }

  @override
  String? get playerId => 'me';

  @override
  Future<void> signIn() async => _check();

  @override
  Future<void> claimName(String name, int tag) async {
    _check();
    if (taken.contains('${name.toLowerCase()}#${'$tag'.padLeft(4, '0')}')) {
      throw const NameTakenException();
    }
    this.name = name;
    this.tag = tag;
  }

  @override
  Future<int?> freeTag(String name) async {
    _check();
    return free;
  }

  @override
  Future<int?> myTag() async {
    _check();
    return tag;
  }

  @override
  Future<void> recordRun(
    GameId game,
    Difficulty difficulty,
    int score,
    Duration duration,
  ) async {
    _check();
    runs.add((game, difficulty, score, duration));
  }

  @override
  Future<Boards> boards() async {
    _check();
    fetches++;
    final rank = this.rank;
    return (
      rows: List<Map<String, dynamic>>.from(rows),
      myRanks: {
        if (rank != null)
          for (final row in rows)
            '${row['game_type']}_${row['difficulty']}': rank,
      },
    );
  }
}
