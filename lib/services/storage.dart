import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';

/// Everything the app keeps on the device.
class Storage {
  Storage(this._prefs);

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  // Keys match the previous app version so existing bests carry over.
  static String _bestKey(GameId game, Difficulty difficulty) =>
      'highScore_${game.name}_${difficulty.name}';

  int best(GameId game, Difficulty difficulty) =>
      _prefs.getInt(_bestKey(game, difficulty)) ?? 0;

  /// Stores [score] if it beats the saved best; returns the best after.
  Future<int> saveBestIfHigher(
    GameId game,
    Difficulty difficulty,
    int score,
  ) async {
    final current = best(game, difficulty);
    if (score > current) {
      await _prefs.setInt(_bestKey(game, difficulty), score);
      return score;
    }
    return current;
  }

  Future<void> resetBests() async {
    for (final game in GameId.values) {
      for (final difficulty in Difficulty.values) {
        await _prefs.remove(_bestKey(game, difficulty));
      }
    }
  }

  bool get soundOn => _prefs.getBool('isSoundEnabled') ?? true;
  Future<void> setSoundOn(bool value) =>
      _prefs.setBool('isSoundEnabled', value);

  bool get vibrationOn => _prefs.getBool('isVibrationEnabled') ?? true;
  Future<void> setVibrationOn(bool value) =>
      _prefs.setBool('isVibrationEnabled', value);

  String? get playerName => _prefs.getString('playerName');
  Future<void> setPlayerName(String value) =>
      _prefs.setString('playerName', value);

  /// Last game + difficulty played, for Home's "Jump back in".
  (GameId, Difficulty)? get lastPlayed {
    final game = GameId.tryParse(_prefs.getString('lastGame') ?? '');
    final difficulty = Difficulty.values
        .where((d) => d.name == _prefs.getString('lastDifficulty'))
        .firstOrNull;
    return game == null || difficulty == null ? null : (game, difficulty);
  }

  Future<void> setLastPlayed(GameId game, Difficulty difficulty) async {
    await _prefs.setString('lastGame', game.name);
    await _prefs.setString('lastDifficulty', difficulty.name);
  }

  /// Cached leaderboard boards as JSON (shape owned by Leaderboard).
  String? get leaderboardCache => _prefs.getString('leaderboardBoards');
  Future<void> setLeaderboardCache(String json) =>
      _prefs.setString('leaderboardBoards', json);

  DateTime? get lastLeaderboardRefresh => _time('leaderboardLastRefreshAt');
  Future<void> setLastLeaderboardRefresh(DateTime at) =>
      _prefs.setInt('leaderboardLastRefreshAt', at.millisecondsSinceEpoch);

  int submissionsOn(String day) =>
      _prefs.getString('leaderboardSubmissionDate') == day
      ? _prefs.getInt('leaderboardSubmissionCount') ?? 0
      : 0;

  Future<void> recordSubmission(String day) async {
    final count = submissionsOn(day) + 1;
    await _prefs.setString('leaderboardSubmissionDate', day);
    await _prefs.setInt('leaderboardSubmissionCount', count);
  }

  DateTime? _time(String key) {
    final millis = _prefs.getInt(key);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
