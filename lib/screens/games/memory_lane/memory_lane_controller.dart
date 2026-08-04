import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';

class MemoryLaneController extends ChangeNotifier {
  MemoryLaneController({
    required this.storage,
    required this.soundService,
    required this.difficulty,
  });

  final LocalStorageService storage;
  final SoundService soundService;
  final DifficultyLevel difficulty;

  bool _isLoading = true;
  bool _isRoundComplete = false;
  int _score = 0;
  int _correctAnswers = 0; // Total correct tile clicks
  int _wrongAnswers = 0; // Mistakes
  int _currentStreak = 0;
  int _maxStreak = 0;
  int _secondsRemaining = 30;

  int _level = 1;
  late final int _gridSize; // 3 for easy (3x3), 4 for medium (4x4), 5 for hard (5x5)
  late int _startingSequenceLength; // Starts at 3 for easy, 4 for medium, 5 for hard
  late int _currentSequenceLength;

  final List<int> _targetSequence = [];
  final List<int> _playerSequence = [];

  bool _isFlashing = false;
  int? _flashingTileIndex;
  Timer? _secondTimer;
  final Random _random = Random();

  bool get isLoading => _isLoading;
  bool get isRoundComplete => _isRoundComplete;
  int get score => _score;
  int get correctAnswers => _correctAnswers;
  int get wrongAnswers => _wrongAnswers;
  int get currentStreak => _currentStreak;
  int get secondsRemaining => _secondsRemaining;
  double get progress => (30 - _secondsRemaining) / 30;

  int get gridSize => _gridSize;
  int get level => _level;
  int get sequenceLength => _currentSequenceLength;
  bool get isTouchEnabled => !_isFlashing && !_isRoundComplete;
  int? get flashingTileIndex => _flashingTileIndex;
  List<int> get targetSequence => _targetSequence;

  GameType get gameType => GameType.memoryLane;

  ScoreModel? get result {
    if (!_isRoundComplete) {
      return null;
    }
    final best = storage.getHighScore(gameType, difficulty);
    return ScoreModel(
      gameType: gameType,
      difficulty: difficulty,
      finalScore: _score,
      bestScore: max(best, _score),
      previousBestScore: best,
      correctAnswers: _correctAnswers,
      wrongAnswers: _wrongAnswers,
      accuracyPercentage: _correctAnswers + _wrongAnswers > 0
          ? (_correctAnswers / (_correctAnswers + _wrongAnswers)) * 100
          : 0,
    );
  }

  Future<void> initialize() async {
    // Setup grid configurations based on difficulty
    switch (difficulty) {
      case DifficultyLevel.easy:
        _gridSize = 3;
        _startingSequenceLength = 3;
        break;
      case DifficultyLevel.medium:
        _gridSize = 4;
        _startingSequenceLength = 4;
        break;
      case DifficultyLevel.hard:
        _gridSize = 5;
        _startingSequenceLength = 5;
        break;
    }
    _currentSequenceLength = _startingSequenceLength;
    _isLoading = false;

    _startSecondTimer();
    _generateAndPlaySequence();
    notifyListeners();
  }

  void _startSecondTimer() {
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _completeRound();
      }
    });
  }

  Future<void> _generateAndPlaySequence() async {
    if (_isRoundComplete) return;

    _isFlashing = true;
    _flashingTileIndex = null;
    _targetSequence.clear();
    _playerSequence.clear();
    notifyListeners();

    // Generate random grid index list (from 0 to gridSize*gridSize - 1)
    final totalTiles = _gridSize * _gridSize;
    for (int i = 0; i < _currentSequenceLength; i++) {
      _targetSequence.add(_random.nextInt(totalTiles));
    }

    // Delay slightly before playing back the flashes
    await Future.delayed(const Duration(milliseconds: 600));

    for (final index in _targetSequence) {
      if (_isRoundComplete) return;
      _flashingTileIndex = index;
      soundService.playCorrect();
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 450)); // Flash duration

      _flashingTileIndex = null;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 150)); // Delay between flashes
    }

    _isFlashing = false;
    notifyListeners();
  }

  Future<void> tapTile(int tileIndex) async {
    if (!isTouchEnabled) return;

    _playerSequence.add(tileIndex);
    final currentStep = _playerSequence.length - 1;

    // Check if the tapped tile matches the target sequence step
    if (_targetSequence[currentStep] == tileIndex) {
      // Correct click!
      _correctAnswers++;
      _score += 10;
      _currentStreak++;
      _maxStreak = max(_maxStreak, _currentStreak);
      soundService.playCorrect();

      // Check if sequence is fully completed
      if (_playerSequence.length == _targetSequence.length) {
        // Round completion bonus!
        _score += 20; // +20 Streak bonus for completing a whole pattern
        _level++;
        _currentSequenceLength++; // Increase difficulty sequence length by 1
        notifyListeners();

        // Pause briefly, then show next sequence
        await Future.delayed(const Duration(milliseconds: 800));
        _generateAndPlaySequence();
      } else {
        notifyListeners();
      }
    } else {
      // Wrong click!
      _wrongAnswers++;
      _currentStreak = 0;
      soundService.playWrong();

      // Momentarily show wrong tap feedback and reset current sequence progress
      _playerSequence.clear();
      notifyListeners();

      // Present the same or new sequence
      await Future.delayed(const Duration(milliseconds: 600));
      _generateAndPlaySequence();
    }
  }

  void _completeRound() {
    _isRoundComplete = true;
    _secondTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _secondTimer?.cancel();
    super.dispose();
  }
}
