import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game/score_calculator.dart';
import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import 'pattern_lock_models.dart';

class PatternLockController extends ChangeNotifier {
  PatternLockController({
    required this.storage,
    required this.soundService,
    required this.difficulty,
    Random? random,
  }) : random = random ?? Random(),
       config = patternLockConfigFor(difficulty);

  final LocalStorageService storage;
  final SoundService soundService;
  final DifficultyLevel difficulty;
  final Random random;
  final GameType gameType = GameType.patternLock;
  final PatternLockConfig config;

  List<int> targetPattern = [];
  List<int> playerPattern = [];

  int score = 0;
  int streak = 0;
  int round = 1;
  int lives = 0;
  int currentPatternLength = 0;
  int correctPatterns = 0;
  int wrongAttempts = 0;

  bool isPreviewing = false;
  bool isAcceptingInput = false;
  bool isRoundComplete = false;
  bool isLoading = true;
  ScoreModel? result;

  int get dotCount => config.gridSize * config.gridSize;

  String get statusMessage {
    if (isRoundComplete) {
      return 'Game over';
    }
    if (isPreviewing) {
      return 'Memorize the pattern';
    }
    if (isAcceptingInput) {
      return 'Tap dots in order, then Submit';
    }
    return 'Get ready…';
  }

  Future<void> initialize() async {
    lives = config.lives;
    currentPatternLength = config.startingLength;
    isLoading = false;
    notifyListeners();
    await _startRound();
  }

  Future<void> _startRound() async {
    if (isRoundComplete) {
      return;
    }

    playerPattern = [];
    targetPattern = _generatePattern(currentPatternLength);
    isPreviewing = true;
    isAcceptingInput = false;
    notifyListeners();

    await Future<void>.delayed(config.previewDuration);

    if (isRoundComplete) {
      return;
    }

    isPreviewing = false;
    isAcceptingInput = true;
    notifyListeners();
  }

  List<int> _generatePattern(int length) {
    final dots = List<int>.generate(dotCount, (index) => index)
      ..shuffle(random);
    return dots.take(length).toList();
  }

  void addDot(int dotIndex) {
    if (!isAcceptingInput || isRoundComplete || isPreviewing) {
      return;
    }
    if (playerPattern.contains(dotIndex)) {
      return;
    }

    playerPattern = [...playerPattern, dotIndex];
    notifyListeners();
  }

  void clearPlayerPattern() {
    if (!isAcceptingInput || isRoundComplete) {
      return;
    }
    playerPattern = [];
    notifyListeners();
  }

  Future<void> submitPattern() async {
    if (!isAcceptingInput || isRoundComplete) {
      return;
    }

    if (_patternsMatch(playerPattern, targetPattern)) {
      await _handleCorrectPattern();
    } else {
      await _handleWrongPattern();
    }

    notifyListeners();
  }

  bool _patternsMatch(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _handleCorrectPattern() async {
    streak++;
    correctPatterns++;
    score = ScoreCalculator.applyCorrect(
      currentScore: score,
      streakAfterCorrect: streak,
    );
    await soundService.playCorrect();

    round++;
    if (currentPatternLength < config.maxLength) {
      currentPatternLength++;
    }

    notifyListeners();
    await _startRound();
  }

  Future<void> _handleWrongPattern() async {
    wrongAttempts++;
    streak = 0;
    lives--;
    await soundService.playWrong();

    if (lives <= 0) {
      await finishRound();
      return;
    }

    notifyListeners();
    await _startRound();
  }

  Future<void> finishRound() async {
    if (isRoundComplete) {
      return;
    }

    isRoundComplete = true;
    isAcceptingInput = false;
    isPreviewing = false;

    final previousBest = storage.getHighScore(gameType, difficulty);
    final bestScore = await storage.saveHighScoreIfHigher(
      gameType,
      difficulty,
      score,
    );

    result = ScoreModel(
      gameType: gameType,
      difficulty: difficulty,
      finalScore: score,
      bestScore: bestScore,
      previousBestScore: previousBest,
      correctAnswers: correctPatterns,
      wrongAnswers: wrongAttempts,
      accuracyPercentage: ScoreUtils.accuracyPercentage(
        correctAnswers: correctPatterns,
        wrongAnswers: wrongAttempts,
      ),
    );
    notifyListeners();
  }

  bool isDotActive(int index) {
    if (isPreviewing) {
      return targetPattern.contains(index);
    }
    return playerPattern.contains(index);
  }
}
