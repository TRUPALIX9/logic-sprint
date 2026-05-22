import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/life_game_constants.dart';
import '../../../core/game/score_calculator.dart';
import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../models/second_life_session.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';

class PatternLockController extends ChangeNotifier {
  PatternLockController({
    required this.storage,
    required this.soundService,
    Random? random,
  }) : random = random ?? Random(),
       gridSize = 3;

  final LocalStorageService storage;
  final SoundService soundService;
  final Random random;
  final int gridSize;
  final GameType gameType = GameType.patternLock;
  final SecondLifeSession secondLife = SecondLifeSession();

  static const DifficultyLevel _storage = LifeGameConstants.storageDifficulty;
  static const Duration previewDuration = Duration(milliseconds: 1400);

  List<int> targetPattern = [];
  List<int> playerPattern = [];

  int lives = LifeGameConstants.startingLives;
  int level = 1;
  int score = 0;
  int bestScore = 0;
  int streak = 0;
  int correctPatterns = 0;
  int wrongAttempts = 0;

  bool isPreviewing = false;
  bool isAcceptingInput = false;
  bool isRoundComplete = false;
  bool isLoading = true;
  ScoreModel? result;

  int get dotCount => gridSize * gridSize;
  int get patternLength => (level + 2).clamp(3, 9);

  bool get isGameplayPaused =>
      secondLife.isPausedForRewardAd || secondLife.awaitingSecondLifeDecision;

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
    resetGame();
    bestScore = storage.getHighScore(gameType, _storage);
    isLoading = false;
    notifyListeners();
    await _startRound();
  }

  Future<void> _startRound() async {
    if (isRoundComplete || isGameplayPaused) {
      return;
    }

    playerPattern = [];
    targetPattern = _generatePattern(patternLength);
    isPreviewing = true;
    isAcceptingInput = false;
    notifyListeners();

    await Future<void>.delayed(previewDuration);

    if (isRoundComplete || isGameplayPaused) {
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
    if (!isAcceptingInput ||
        isRoundComplete ||
        isPreviewing ||
        isGameplayPaused) {
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
    if (!isAcceptingInput || isRoundComplete || isGameplayPaused) {
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
    level += 1;

    notifyListeners();
    await _startRound();
  }

  Future<void> _handleWrongPattern() async {
    wrongAttempts++;
    streak = 0;
    lives -= 1;
    await soundService.playWrong();

    if (lives <= 0) {
      _offerGameOverOrSecondLife();
      return;
    }

    notifyListeners();
    await _replayCurrentPattern();
  }

  void _offerGameOverOrSecondLife() {
    if (!secondLife.secondLifeUsed) {
      secondLife.pauseForSecondLifeOffer();
      notifyListeners();
      return;
    }
    unawaited(endGameFinal());
  }

  Future<void> resumeFromSecondLifeReward() async {
    secondLife.markSecondLifeUsed();
    lives = 1;
    playerPattern = [];
    await _replayCurrentPattern();
    notifyListeners();
  }

  Future<void> _replayCurrentPattern() async {
    isPreviewing = true;
    isAcceptingInput = false;
    notifyListeners();

    await Future<void>.delayed(previewDuration);

    if (isRoundComplete || isGameplayPaused) {
      return;
    }

    isPreviewing = false;
    isAcceptingInput = true;
    playerPattern = [];
    notifyListeners();
  }

  Future<void> endGameFinal() async {
    if (isRoundComplete) {
      return;
    }

    secondLife.endGameFinal();
    isRoundComplete = true;
    isAcceptingInput = false;
    isPreviewing = false;

    final previousBest = bestScore;
    bestScore = await storage.saveHighScoreIfHigher(gameType, _storage, score);

    result = ScoreModel(
      gameType: gameType,
      difficulty: _storage,
      finalScore: score,
      bestScore: bestScore,
      previousBestScore: previousBest,
      correctAnswers: correctPatterns,
      wrongAnswers: wrongAttempts,
      accuracyPercentage: ScoreUtils.accuracyPercentage(
        correctAnswers: correctPatterns,
        wrongAnswers: wrongAttempts,
      ),
      level: level,
      usedSecondLife: secondLife.secondLifeUsed,
    );
    notifyListeners();
  }

  void resetGame() {
    secondLife.reset();
    isRoundComplete = false;
    result = null;
    lives = LifeGameConstants.startingLives;
    level = 1;
    score = 0;
    streak = 0;
    correctPatterns = 0;
    wrongAttempts = 0;
    isPreviewing = false;
    isAcceptingInput = false;
    targetPattern = [];
    playerPattern = [];
    isLoading = false;
  }

  bool isDotActive(int index) {
    if (isPreviewing) {
      return targetPattern.contains(index);
    }
    return playerPattern.contains(index);
  }
}
