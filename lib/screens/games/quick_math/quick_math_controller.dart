import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/life_game_constants.dart';
import '../../../core/utils/random_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/question_model.dart';
import '../../../models/score_model.dart';
import '../../../models/second_life_session.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';

class QuickMathController extends ChangeNotifier {
  QuickMathController({
    required this.storage,
    required this.soundService,
    Random? random,
  }) : random = random ?? Random();

  final LocalStorageService storage;
  final SoundService soundService;
  final Random random;
  final SecondLifeSession secondLife = SecondLifeSession();

  static const DifficultyLevel _storage = LifeGameConstants.storageDifficulty;

  QuestionModel? currentQuestion;
  int lives = LifeGameConstants.startingLives;
  int level = 1;
  int score = 0;
  int bestScore = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int currentStreak = 0;
  bool isLoading = true;
  bool isAnswerLocked = false;
  bool isRoundComplete = false;
  bool? lastAnswerCorrect;
  String? selectedAnswer;
  ScoreModel? result;

  Timer? _feedbackTimer;

  bool get isGameplayPaused =>
      secondLife.isPausedForRewardAd || secondLife.awaitingSecondLifeDecision;

  double get accuracy => ScoreUtils.accuracyPercentage(
    correctAnswers: correctAnswers,
    wrongAnswers: wrongAnswers,
  );

  Future<void> initialize() async {
    resetGame();
    bestScore = storage.getHighScore(GameType.quickMath, _storage);
    currentQuestion = _buildQuestion();
    isLoading = false;
    notifyListeners();
  }

  QuestionModel _buildQuestion() =>
      QuickMathQuestionFactory.createForLevel(level, random: random);

  Future<void> submitAnswer(String answer) async {
    if (isRoundComplete || isAnswerLocked || currentQuestion == null) {
      return;
    }
    if (isGameplayPaused) {
      return;
    }

    isAnswerLocked = true;
    selectedAnswer = answer;
    final isCorrect = answer == currentQuestion!.correctAnswer;
    lastAnswerCorrect = isCorrect;

    if (isCorrect) {
      correctAnswers += 1;
      currentStreak += 1;
      score += ScoreUtils.correctAnswerPoints;
      if (currentStreak % ScoreUtils.streakBonusEvery == 0) {
        score += ScoreUtils.streakBonusPoints;
      }
      if (correctAnswers % 3 == 0) {
        level += 1;
      }
      await soundService.playCorrect();
      notifyListeners();

      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 400), () {
        if (isRoundComplete || isGameplayPaused) {
          return;
        }
        currentQuestion = _buildQuestion();
        isAnswerLocked = false;
        lastAnswerCorrect = null;
        selectedAnswer = null;
        notifyListeners();
      });
      return;
    }

    wrongAnswers += 1;
    currentStreak = 0;
    lives -= 1;
    await soundService.playWrong();
    notifyListeners();

    if (lives <= 0) {
      _offerGameOverOrSecondLife();
      return;
    }

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 550), () {
      if (isRoundComplete || isGameplayPaused) {
        return;
      }
      currentQuestion = _buildQuestion();
      isAnswerLocked = false;
      lastAnswerCorrect = null;
      selectedAnswer = null;
      notifyListeners();
    });
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
    isAnswerLocked = false;
    lastAnswerCorrect = null;
    selectedAnswer = null;
    currentQuestion = _buildQuestion();
    notifyListeners();
  }

  Future<void> endGameFinal() async {
    if (isRoundComplete) {
      return;
    }
    secondLife.endGameFinal();
    isRoundComplete = true;
    _feedbackTimer?.cancel();
    final previousBest = bestScore;
    bestScore = await storage.saveHighScoreIfHigher(
      GameType.quickMath,
      _storage,
      score,
    );
    result = ScoreModel(
      gameType: GameType.quickMath,
      difficulty: _storage,
      finalScore: score,
      bestScore: bestScore,
      previousBestScore: previousBest,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      accuracyPercentage: accuracy,
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
    correctAnswers = 0;
    wrongAnswers = 0;
    currentStreak = 0;
    isAnswerLocked = false;
    lastAnswerCorrect = null;
    selectedAnswer = null;
    isLoading = false;
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }
}

enum _MathOperation { addition, subtraction, multiplication, division }

class QuickMathQuestionFactory {
  static QuestionModel createForLevel(int level, {Random? random}) {
    final rng = random ?? Random();
    final tier = level.clamp(1, 99);
    final operation = _pickOperation(tier, rng);
    final maxNumber = switch (tier) {
      <= 1 => 9,
      <= 2 => 20,
      <= 3 => 35,
      <= 4 => 50,
      _ => 99,
    };

    late final int left;
    late final int right;
    late final int answer;
    late final String symbol;

    switch (operation) {
      case _MathOperation.addition:
        left = rng.nextInt(maxNumber) + 1;
        right = rng.nextInt(maxNumber) + 1;
        answer = left + right;
        symbol = '+';
      case _MathOperation.subtraction:
        final first = rng.nextInt(maxNumber) + 1;
        final second = rng.nextInt(maxNumber) + 1;
        left = max(first, second);
        right = min(first, second);
        answer = left - right;
        symbol = '-';
      case _MathOperation.multiplication:
        final multCap = tier <= 2 ? 6 : 12;
        left = rng.nextInt(multCap) + 2;
        right = rng.nextInt(multCap) + 2;
        answer = left * right;
        symbol = '×';
      case _MathOperation.division:
        right = rng.nextInt(11) + 2;
        final quotient = rng.nextInt(11) + 2;
        left = right * quotient;
        answer = quotient;
        symbol = '÷';
    }

    final spread = tier >= 5
        ? 24
        : tier >= 3
        ? 14
        : 8;
    final options = buildNearbyUniqueAnswers(
      correctAnswer: answer,
      count: 3,
      random: rng,
      minValue: 0,
      spread: spread,
    );

    return QuestionModel(
      prompt: '$left $symbol $right = ?',
      correctAnswer: '$answer',
      options: options.map((option) => '$option').toList(),
    );
  }

  static _MathOperation _pickOperation(int level, Random random) {
    final choices = switch (level) {
      <= 1 => [_MathOperation.addition, _MathOperation.subtraction],
      <= 3 => [
        _MathOperation.addition,
        _MathOperation.subtraction,
        _MathOperation.multiplication,
      ],
      _ => _MathOperation.values,
    };
    return choices[random.nextInt(choices.length)];
  }
}
