import 'package:flutter/material.dart';

import '../models/game_model.dart';
import 'local_storage_service.dart';
import 'sound_service.dart';

class AppState extends ChangeNotifier {
  AppState._({
    required this.storage,
    required this.soundService,
    required ThemeMode themeMode,
    required bool isSoundEnabled,
    required bool isVibrationEnabled,
    required String adMode,
    required Map<String, int> highScores,
  })  : _themeMode = themeMode,
        _isSoundEnabled = isSoundEnabled,
        _isVibrationEnabled = isVibrationEnabled,
        _adMode = adMode,
        _highScores = highScores;

  final LocalStorageService storage;
  final SoundService soundService;

  ThemeMode _themeMode;
  bool _isSoundEnabled;
  bool _isVibrationEnabled;
  String _adMode;
  final Map<String, int> _highScores;

  static Future<AppState> create({
    required LocalStorageService storage,
    required SoundService soundService,
  }) async {
    final soundEnabled = storage.getSoundEnabled();
    final state = AppState._(
      storage: storage,
      soundService: soundService,
      themeMode: storage.getThemeMode(),
      isSoundEnabled: soundEnabled,
      isVibrationEnabled: storage.getVibrationEnabled(),
      adMode: storage.getAdMode(),
      highScores: <String, int>{},
    );
    await state.refreshHighScores();
    soundService.setEnabled(soundEnabled);
    return state;
  }

  ThemeMode get themeMode => _themeMode;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;
  String get adMode => _adMode;

  Future<void> refreshHighScores() async {
    for (final gameType in GameType.values.where((game) => game.isPlayable)) {
      for (final difficulty in DifficultyLevel.values) {
        _highScores[_mapKey(gameType, difficulty)] =
            storage.getHighScore(gameType, difficulty);
      }
    }
    notifyListeners();
  }

  int bestScoreFor(GameType gameType, DifficultyLevel difficulty) {
    return _highScores[_mapKey(gameType, difficulty)] ?? 0;
  }

  int overallBestFor(GameType gameType) {
    return DifficultyLevel.values
        .map((difficulty) => bestScoreFor(gameType, difficulty))
        .fold<int>(0, (best, score) => score > best ? score : best);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await storage.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _isSoundEnabled = value;
    soundService.setEnabled(value);
    await storage.setSoundEnabled(value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _isVibrationEnabled = value;
    await storage.setVibrationEnabled(value);
    notifyListeners();
  }

  Future<void> setAdMode(String mode) async {
    _adMode = mode;
    await storage.setAdMode(mode);
    notifyListeners();
  }

  Future<void> resetHighScores() async {
    await storage.resetHighScores();
    await refreshHighScores();
  }

  Future<void> recordHighScore(
    GameType gameType,
    DifficultyLevel difficulty,
    int score,
  ) async {
    final best = await storage.saveHighScoreIfHigher(gameType, difficulty, score);
    _highScores[_mapKey(gameType, difficulty)] = best;
    notifyListeners();
  }

  String _mapKey(GameType gameType, DifficultyLevel difficulty) =>
      '${gameType.storageKey}_${difficulty.storageKey}';
}
