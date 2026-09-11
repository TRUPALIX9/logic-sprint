import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import '../models/run_record.dart';

/// Everything the app keeps on the device.
class Storage {
  Storage(this._prefs);

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  /// History keeps the most recent runs only.
  static const historyLimit = 100;

  final SharedPreferences _prefs;

  // Keys match the previous app version so existing bests carry over.
  static String _bestKey(GameId game, Difficulty difficulty) =>
      'highScore_${game.name}_${difficulty.name}';

  static String _timeKey(GameId game, Difficulty difficulty) =>
      'bestTime_${game.name}_${difficulty.name}';

  static String _playsKey(GameId game, Difficulty difficulty) =>
      'plays_${game.name}_${difficulty.name}';

  int best(GameId game, Difficulty difficulty) =>
      _prefs.getInt(_bestKey(game, difficulty)) ?? 0;

  /// Runs finished on this device.
  int plays(GameId game, Difficulty difficulty) =>
      _prefs.getInt(_playsKey(game, difficulty)) ?? 0;

  Future<void> addPlay(GameId game, Difficulty difficulty) =>
      _prefs.setInt(_playsKey(game, difficulty), plays(game, difficulty) + 1);

  /// How long the best-scoring run took, if recorded.
  Duration? bestTime(GameId game, Difficulty difficulty) {
    final millis = _prefs.getInt(_timeKey(game, difficulty));
    return millis == null ? null : Duration(milliseconds: millis);
  }

  /// Stores [score] and its [duration] if the score beats the saved best, or
  /// ties it in less time. Returns the best after.
  Future<int> saveBestIfHigher(
    GameId game,
    Difficulty difficulty,
    int score, {
    Duration? duration,
  }) async {
    final current = best(game, difficulty);
    final currentTime = bestTime(game, difficulty);
    final faster =
        duration != null && (currentTime == null || duration < currentTime);
    if (score > current || (score == current && score > 0 && faster)) {
      await _prefs.setInt(_bestKey(game, difficulty), score);
      if (duration != null) {
        await _prefs.setInt(
          _timeKey(game, difficulty),
          duration.inMilliseconds,
        );
      }
      return score;
    }
    return current;
  }

  Future<void> resetBests() async {
    for (final game in GameId.values) {
      for (final difficulty in Difficulty.values) {
        await _prefs.remove(_bestKey(game, difficulty));
        await _prefs.remove(_timeKey(game, difficulty));
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

  /// Local run history, newest first.
  List<RunRecord> get history => _records('runHistory');

  Future<void> addHistory(RunRecord run) =>
      _setRecords('runHistory', [run, ...history].take(historyLimit).toList());

  /// Runs not yet sent to the server, oldest first.
  List<RunRecord> get pendingRuns => _records('pendingRuns');
  Future<void> setPendingRuns(List<RunRecord> runs) =>
      _setRecords('pendingRuns', runs);

  /// Cached leaderboard boards as JSON (shape owned by Leaderboard).
  String? get leaderboardCache => _prefs.getString('leaderboardBoards');
  Future<void> setLeaderboardCache(String json) =>
      _prefs.setString('leaderboardBoards', json);

  DateTime? get lastLeaderboardRefresh {
    final millis = _prefs.getInt('leaderboardLastRefreshAt');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastLeaderboardRefresh(DateTime at) =>
      _prefs.setInt('leaderboardLastRefreshAt', at.millisecondsSinceEpoch);

  List<RunRecord> _records(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return [];
    }
    try {
      return (jsonDecode(raw) as List)
          .map((e) => RunRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .nonNulls
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _setRecords(String key, List<RunRecord> runs) =>
      _prefs.setString(key, jsonEncode([for (final r in runs) r.toJson()]));
}
