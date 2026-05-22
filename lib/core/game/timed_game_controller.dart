import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/second_life_session.dart';
import '../utils/score_utils.dart';
import '../../models/game_model.dart';
import '../../models/question_model.dart';
import '../../models/score_model.dart';
import '../../services/local_storage_service.dart';
import '../../services/sound_service.dart';

abstract class TimedGameController extends ChangeNotifier {
  TimedGameController({
    required this.storage,
    required this.soundService,
    required this.gameType,
    required this.difficulty,
    Random? random,
    this.offerSecondLifeOnWrongAnswer = false,
  }) : random = random ?? Random();

  final LocalStorageService storage;
  final SoundService soundService;
  final GameType gameType;
  final DifficultyLevel difficulty;
  final Random random;
  final bool offerSecondLifeOnWrongAnswer;

  final SecondLifeSession secondLife = SecondLifeSession();

  Timer? _roundTimer;
  Timer? _nextQuestionTimer;

  QuestionModel? currentQuestion;
  int secondsRemaining = ScoreUtils.roundLengthSeconds;
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

  double get progress =>
      secondsRemaining / ScoreUtils.roundLengthSeconds.clamp(1, 999);

  double get accuracy => ScoreUtils.accuracyPercentage(
    correctAnswers: correctAnswers,
    wrongAnswers: wrongAnswers,
  );

  bool get isGameplayPaused =>
      secondLife.isPausedForRewardAd || secondLife.awaitingSecondLifeDecision;

  Future<void> initialize() async {
    secondLife.reset();
    bestScore = storage.getHighScore(gameType, difficulty);
    currentQuestion = buildQuestion();
    isLoading = false;
    notifyListeners();
    _startTimer();
  }

  QuestionModel buildQuestion();

  void _startTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isGameplayPaused) {
        return;
      }
      if (secondsRemaining <= 1) {
        secondsRemaining = 0;
        timer.cancel();
        unawaited(finishRound());
      } else {
        secondsRemaining -= 1;
        notifyListeners();
      }
    });
  }

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
      await soundService.playCorrect();
      notifyListeners();

      _nextQuestionTimer?.cancel();
      _nextQuestionTimer = Timer(const Duration(milliseconds: 350), () {
        if (isRoundComplete || isGameplayPaused) {
          return;
        }
        currentQuestion = buildQuestion();
        isAnswerLocked = false;
        lastAnswerCorrect = null;
        selectedAnswer = null;
        notifyListeners();
      });
      return;
    }

    wrongAnswers += 1;
    currentStreak = 0;
    await soundService.playWrong();
    notifyListeners();

    if (offerSecondLifeOnWrongAnswer && !secondLife.secondLifeUsed) {
      _roundTimer?.cancel();
      _nextQuestionTimer?.cancel();
      secondLife.pauseForSecondLifeOffer();
      notifyListeners();
      return;
    }

    _nextQuestionTimer?.cancel();
    _nextQuestionTimer = Timer(const Duration(milliseconds: 350), () {
      if (isRoundComplete || isGameplayPaused) {
        return;
      }
      currentQuestion = buildQuestion();
      isAnswerLocked = false;
      lastAnswerCorrect = null;
      selectedAnswer = null;
      notifyListeners();
    });
  }

  Future<void> finishRound() async {
    if (isRoundComplete) {
      return;
    }

    _roundTimer?.cancel();
    _nextQuestionTimer?.cancel();

    if (!secondLife.secondLifeUsed) {
      secondLife.pauseForSecondLifeOffer();
      notifyListeners();
      return;
    }

    await endGameFinal();
  }

  Future<void> resumeFromSecondLifeReward() async {
    secondLife.markSecondLifeUsed();
    isAnswerLocked = false;
    lastAnswerCorrect = null;
    selectedAnswer = null;
    currentQuestion = buildQuestion();
    if (secondsRemaining <= 0) {
      secondsRemaining = ScoreUtils.roundLengthSeconds;
    }
    _startTimer();
    notifyListeners();
  }

  Future<void> endGameFinal() async {
    if (isRoundComplete) {
      return;
    }

    secondLife.endGameFinal();
    isRoundComplete = true;
    _roundTimer?.cancel();
    _nextQuestionTimer?.cancel();
    final previousBest = bestScore;
    bestScore = await storage.saveHighScoreIfHigher(
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
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      accuracyPercentage: accuracy,
    );
    notifyListeners();
  }

  void resetGame() {
    secondLife.reset();
    isRoundComplete = false;
    result = null;
    score = 0;
    correctAnswers = 0;
    wrongAnswers = 0;
    currentStreak = 0;
    secondsRemaining = ScoreUtils.roundLengthSeconds;
    isAnswerLocked = false;
    lastAnswerCorrect = null;
    selectedAnswer = null;
    isLoading = false;
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _nextQuestionTimer?.cancel();
    super.dispose();
  }
}
