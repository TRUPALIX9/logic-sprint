import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';

class Asteroid {
  Asteroid({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });

  final String id;
  double x; // 0.0 to 1.0 (relative width)
  double y; // 0.0 to 1.0 (relative height)
  final double size;
  final double speed;
}

class RocketLaunchController extends ChangeNotifier {
  RocketLaunchController({
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
  int _correctAnswers = 0; // Dodged asteroids
  int _wrongAnswers = 0; // Collisions
  int _currentStreak = 0;
  int _maxStreak = 0;
  int _secondsRemaining = 30;

  double _rocketX = 0.5; // 0.0 to 1.0
  final List<Asteroid> _asteroids = [];
  Timer? _gameTimer;
  Timer? _secondTimer;
  final Random _random = Random();
  int _tickCount = 0;

  bool get isLoading => _isLoading;
  bool get isRoundComplete => _isRoundComplete;
  int get score => _score;
  int get correctAnswers => _correctAnswers;
  int get wrongAnswers => _wrongAnswers;
  int get currentStreak => _currentStreak;
  int get secondsRemaining => _secondsRemaining;
  double get progress => (30 - _secondsRemaining) / 30;
  double get rocketX => _rocketX;
  List<Asteroid> get asteroids => _asteroids;

  GameType get gameType => GameType.rocketLaunch;

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
    _isLoading = false;
    _startTimers();
    notifyListeners();
  }

  void _startTimers() {
    // Game loop at ~60 FPS (approx 16ms per tick)
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _gameTick();
    });

    // 30 seconds countdown timer
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        // Standard survival bonus every second
        _score += 5;
        notifyListeners();
      } else {
        _completeRound();
      }
    });
  }

  void moveRocketLeft() {
    if (_isRoundComplete) return;
    _rocketX = (_rocketX - 0.08).clamp(0.05, 0.95);
    notifyListeners();
  }

  void moveRocketRight() {
    if (_isRoundComplete) return;
    _rocketX = (_rocketX + 0.08).clamp(0.05, 0.95);
    notifyListeners();
  }

  void moveRocketTo(double x) {
    if (_isRoundComplete) return;
    _rocketX = x.clamp(0.05, 0.95);
    notifyListeners();
  }

  void _gameTick() {
    if (_isRoundComplete) return;
    _tickCount++;

    // Speed multiplier based on difficulty & elapsed time
    double speedMultiplier = 1.0;
    switch (difficulty) {
      case DifficultyLevel.easy:
        speedMultiplier = 1.0 + (30 - _secondsRemaining) * 0.02;
        break;
      case DifficultyLevel.medium:
        speedMultiplier = 1.3 + (30 - _secondsRemaining) * 0.03;
        break;
      case DifficultyLevel.hard:
        speedMultiplier = 1.6 + (30 - _secondsRemaining) * 0.04;
        break;
    }

    // Spawn asteroids
    int spawnInterval = difficulty == DifficultyLevel.easy
        ? 45
        : (difficulty == DifficultyLevel.medium ? 35 : 25);
    // Get faster with time
    spawnInterval = (spawnInterval - (30 - _secondsRemaining) ~/ 3).clamp(12, 100);

    if (_tickCount % spawnInterval == 0) {
      _spawnAsteroid(speedMultiplier);
    }

    // Update asteroid positions & collision detection
    for (int i = _asteroids.length - 1; i >= 0; i--) {
      final asteroid = _asteroids[i];
      asteroid.y += asteroid.speed * 0.008 * speedMultiplier;

      // Check collision
      // Rocket is located at y = 0.85
      if (asteroid.y >= 0.80 && asteroid.y <= 0.90) {
        double xDiff = (asteroid.x - _rocketX).abs();
        if (xDiff < 0.12) {
          _handleCollision(asteroid);
          _asteroids.removeAt(i);
          continue;
        }
      }

      // Check successfully dodged
      if (asteroid.y >= 1.0) {
        _handleDodge();
        _asteroids.removeAt(i);
      }
    }

    notifyListeners();
  }

  void _spawnAsteroid(double speedMultiplier) {
    final size = 20.0 + _random.nextDouble() * 25.0;
    final speed = 1.0 + _random.nextDouble() * 1.5;
    _asteroids.add(Asteroid(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      x: 0.05 + _random.nextDouble() * 0.9,
      y: 0.0,
      size: size,
      speed: speed,
    ));
  }

  void _handleCollision(Asteroid asteroid) {
    _wrongAnswers++;
    _currentStreak = 0;
    _score = max(0, _score - 15); // Collision penalty
    soundService.playWrong();
    notifyListeners();
  }

  void _handleDodge() {
    _correctAnswers++;
    _currentStreak++;
    _maxStreak = max(_maxStreak, _currentStreak);

    // LogicSprint standard points + streak bonuses
    int pointsGained = 10;
    if (_currentStreak > 0 && _currentStreak % 5 == 0) {
      pointsGained += 20; // +20 Streak bonus!
      soundService.playCorrect();
    } else {
      soundService.playCorrect();
    }
    _score += pointsGained;
    notifyListeners();
  }

  void _completeRound() {
    _isRoundComplete = true;
    _gameTimer?.cancel();
    _secondTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _secondTimer?.cancel();
    super.dispose();
  }
}
