import '../core/utils/player_name_validator.dart';
import '../models/game_model.dart';
import 'firebase_leaderboard_service.dart';
import 'local_storage_service.dart';

export 'firebase_leaderboard_service.dart' show LeaderboardFetchResult;

/// UI-facing leaderboard API (all-time, daily cache refresh).
class LeaderboardService {
  LeaderboardService({
    required LocalStorageService storage,
    required FirebaseLeaderboardService firebaseLeaderboard,
  }) : _storage = storage,
       _firebase = firebaseLeaderboard;

  final LocalStorageService _storage;
  final FirebaseLeaderboardService _firebase;

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

  Future<LeaderboardFetchResult> loadLeaderboard({
    required GameType gameType,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      return _firebase.fetchAllTimeLeaderboard(
        gameType: gameType,
        forceRefresh: true,
      );
    }

    return _firebase.fetchAllTimeLeaderboard(gameType: gameType);
  }

  Future<void> syncPendingSubmissions() =>
      _firebase.syncPendingAllTimeSubmissions();
}
