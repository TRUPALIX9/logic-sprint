import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/services/leaderboard_api.dart';

/// In-memory [LeaderboardApi] for tests. Flip [online] to simulate outages.
class FakeLeaderboardApi implements LeaderboardApi {
  FakeLeaderboardApi({this.rows = const [], this.rank});

  /// Rows served by [top] (filtered to the requested board).
  List<Map<String, dynamic>> rows;
  int? rank;
  bool online = true;
  String? name;
  final takenNames = <String>{};
  final runs = <(GameId, Difficulty, int, Duration)>[];
  final topCalls = <(GameId, Difficulty)>[];

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
  Future<void> claimName(String name) async {
    _check();
    if (takenNames.contains(name.toLowerCase())) {
      throw const NameTakenException();
    }
    this.name = name;
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
  Future<List<Map<String, dynamic>>> top(
    GameId game,
    Difficulty difficulty,
  ) async {
    _check();
    topCalls.add((game, difficulty));
    return rows
        .where(
          (r) =>
              r['game_type'] == game.name && r['difficulty'] == difficulty.name,
        )
        .toList();
  }

  @override
  Future<int?> myRank(GameId game, Difficulty difficulty) async {
    _check();
    return rank;
  }
}
