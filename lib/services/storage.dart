import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_log.dart';
import '../models/game.dart';
import '../models/run_record.dart';

/// Everything the app keeps on the device.
class Storage {
  Storage(this._prefs);

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

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

  /// Hearts: stored revives, spendable in any game. Only earned by ads.
  int get hearts => _prefs.getInt('hearts') ?? 0;
  Future<void> setHearts(int value) => _prefs.setInt('hearts', value);

  /// True after a finished run until its one heart ad is watched.
  bool get heartAdUnlocked => _prefs.getBool('heartAdUnlocked') ?? false;
  Future<void> setHeartAdUnlocked(bool value) =>
      _prefs.setBool('heartAdUnlocked', value);

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

  bool get musicOn => _prefs.getBool('isMusicEnabled') ?? true;
  Future<void> setMusicOn(bool value) =>
      _prefs.setBool('isMusicEnabled', value);

  bool get vibrationOn => _prefs.getBool('isVibrationEnabled') ?? true;
  Future<void> setVibrationOn(bool value) =>
      _prefs.setBool('isVibrationEnabled', value);

  /// Rocket Launch easter-egg lines this player has already seen.
  List<String> get whispersSeen => _prefs.getStringList('whispersSeen') ?? [];
  Future<void> setWhispersSeen(List<String> lines) =>
      _prefs.setStringList('whispersSeen', lines);

  /// Rocket Launch ship, by [ShipKind.name].
  String? get rocketShip => _prefs.getString('rocketShip');
  Future<void> setRocketShip(String value) =>
      _prefs.setString('rocketShip', value);

  String? get playerName => _prefs.getString('playerName');
  Future<void> setPlayerName(String value) =>
      _prefs.setString('playerName', value);

  /// The 4-digit tag that goes with [playerName] ("NAME#0420").
  int? get playerTag => _prefs.getInt('playerTag');
  Future<void> setPlayerTag(int value) => _prefs.setInt('playerTag', value);

  /// Forgets the leaderboard identity: name, tag, unsent runs and cached
  /// boards (after the server data is deleted). Local bests and History stay.
  Future<void> clearPlayer() async {
    for (final key in [
      'playerName',
      'playerTag',
      'pendingRuns',
      'leaderboardBoards',
    ]) {
      await _prefs.remove(key);
    }
  }

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

  /// Local run history, newest first. Every run is kept: rows are compact
  /// (see [RunRecord.toRow]) and decoded once, then served from memory.
  List<RunRecord> get history => _history ??= List.unmodifiable(_readHistory());
  List<RunRecord>? _history;

  Future<void> addHistory(RunRecord run) {
    final runs = [run, ...history];
    _history = List.unmodifiable(runs);
    return _prefs.setString(
      _historyKey,
      jsonEncode([for (final r in runs) r.toRow()]),
    );
  }

  static const _historyKey = 'runHistory';

  /// The most recent video ads shown here, oldest first (banners are only
  /// counted). Capped at [adLogLimit] so it stays small. Kept only here.
  List<AdEvent> get adLog => _adLog ??= List.unmodifiable(
    _rows('adLog').map(AdEvent.fromRow).nonNulls,
  );
  List<AdEvent>? _adLog;

  static const adLogLimit = 500;

  /// Running totals per kind and outcome ("revive.rewarded": 12). They
  /// never drop old ads, and a banner only bumps a number.
  Map<String, int> get _adTotals => _adTotalsCache ??= _readTotals();
  Map<String, int>? _adTotalsCache;

  Map<String, int> _readTotals() {
    try {
      final raw = jsonDecode(_prefs.getString('adTotals') ?? '{}') as Map;
      return {
        for (final MapEntry(:key, :value) in raw.entries)
          if (value is num) '$key': value.toInt(),
      };
    } on Object {
      return {};
    }
  }

  Future<void> addAdEvent(AdEvent event) async {
    final key = '${event.kind.name}.${event.outcome.name}';
    final totals = {..._adTotals, key: (_adTotals[key] ?? 0) + 1};
    _adTotalsCache = totals;
    await _prefs.setString('adTotals', jsonEncode(totals));
    if (event.kind == AdKind.banner) {
      return;
    }
    final events = [...adLog, event];
    final kept = events.length > adLogLimit
        ? events.sublist(events.length - adLogLimit)
        : events;
    _adLog = List.unmodifiable(kept);
    await _prefs.setString(
      'adLog',
      jsonEncode([for (final e in kept) e.toRow()]),
    );
  }

  /// How many ads of each kind were shown here, all time.
  Map<AdKind, int> get adCounts => {
    for (final kind in AdKind.values) kind: adCount(kind),
  };

  /// Shown ads of [kind], optionally only those with [outcome].
  int adCount(AdKind kind, [AdOutcome? outcome]) => [
    for (final o in AdOutcome.values)
      if (outcome == null || o == outcome)
        _adTotals['${kind.name}.${o.name}'] ?? 0,
  ].fold(0, (a, b) => a + b);

  /// Every name this player has taken, oldest first. Kept only here; it
  /// stays when the leaderboard data is deleted from the server.
  List<NameUse> get nameLog =>
      List.unmodifiable(_rows('nameLog').map(NameUse.fromRow).nonNulls);

  Future<void> addNameUse(NameUse use) => _prefs.setString(
    'nameLog',
    jsonEncode([
      for (final n in [...nameLog, use]) n.toRow(),
    ]),
  );

  List<Object?> _rows(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return const [];
    }
    try {
      return jsonDecode(raw) as List;
    } on Object {
      return const [];
    }
  }

  /// Reads both the compact rows and the older map-per-run format.
  List<RunRecord> _readHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) {
      return [];
    }
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is List)
            RunRecord.fromRow(e)
          else if (e is Map)
            RunRecord.fromJson(Map<String, dynamic>.from(e)),
      ].nonNulls.toList();
    } on Object {
      return [];
    }
  }

  /// Runs not yet sent to the server, oldest first.
  List<RunRecord> get pendingRuns => _records('pendingRuns');
  Future<void> setPendingRuns(List<RunRecord> runs) =>
      _setRecords('pendingRuns', runs);

  /// Cached leaderboard boards as JSON (shape owned by Leaderboard).
  String? get leaderboardCache => _prefs.getString('leaderboardBoards');
  Future<void> setLeaderboardCache(String json) =>
      _prefs.setString('leaderboardBoards', json);

  /// When "Refresh ▶" last fetched the boards.
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
