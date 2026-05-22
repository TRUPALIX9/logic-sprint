import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/life_game_constants.dart';
import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../models/second_life_session.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';

enum SequenceColor { blue, orange, cyan, purple }

enum ColorSequencePhase { idle, watching, repeating, feedback }

extension SequenceColorX on SequenceColor {
  String get label {
    switch (this) {
      case SequenceColor.blue:
        return 'Blue';
      case SequenceColor.orange:
        return 'Orange';
      case SequenceColor.cyan:
        return 'Cyan';
      case SequenceColor.purple:
        return 'Purple';
    }
  }
}

class ColorSequenceController extends ChangeNotifier {
  ColorSequenceController({
    required this.storage,
    required this.soundService,
    Random? random,
  }) : random = random ?? Random();

  final LocalStorageService storage;
  final SoundService soundService;
  final Random random;
  final SecondLifeSession secondLife = SecondLifeSession();

  static const DifficultyLevel _storage = LifeGameConstants.storageDifficulty;
  static const List<SequenceColor> palette = SequenceColor.values;

  Timer? _phaseTimer;

  int lives = LifeGameConstants.startingLives;
  int level = 1;
  int score = 0;
  int bestScore = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int currentStreak = 0;
  int? highlightedIndex;
  bool isLoading = true;
  bool isRoundComplete = false;
  ColorSequencePhase phase = ColorSequencePhase.idle;
  String instruction = 'Watch the pattern';
  String? feedbackMessage;
  List<SequenceColor> targetSequence = [];
  List<SequenceColor> playerSequence = [];
  ScoreModel? result;

  int get sequenceLength => (level + 1).clamp(2, 12);

  List<SequenceColor> get activePalette =>
      level >= 3 ? palette : palette.take(3).toList();

  double get accuracy => ScoreUtils.accuracyPercentage(
    correctAnswers: correctAnswers,
    wrongAnswers: wrongAnswers,
  );

  bool get canTapColors =>
      phase == ColorSequencePhase.repeating &&
      !isRoundComplete &&
      !isGameplayPaused;

  bool get isGameplayPaused =>
      secondLife.isPausedForRewardAd || secondLife.awaitingSecondLifeDecision;

  Future<void> initialize() async {
    resetGame();
    bestScore = storage.getHighScore(GameType.colorSequence, _storage);
    isLoading = false;
    notifyListeners();
    await _startRound();
  }

  static int sequenceLengthForLevel(int level) => (level + 1).clamp(2, 12);

  List<SequenceColor> generateSequence(int length) {
    final colors = activePalette;
    return List<SequenceColor>.generate(
      length,
      (_) => colors[random.nextInt(colors.length)],
    );
  }

  Future<void> _startRound() async {
    if (isRoundComplete) {
      return;
    }

    _phaseTimer?.cancel();
    targetSequence = generateSequence(sequenceLength);
    playerSequence = [];
    highlightedIndex = null;
    feedbackMessage = null;
    phase = ColorSequencePhase.watching;
    instruction = 'Watch the pattern';
    notifyListeners();

    final playbackMs = level >= 4 ? 420 : 550;
    for (var i = 0; i < targetSequence.length; i++) {
      if (isRoundComplete || isGameplayPaused) {
        return;
      }
      highlightedIndex = i;
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: playbackMs));
      highlightedIndex = null;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }

    if (isRoundComplete) {
      return;
    }

    phase = ColorSequencePhase.repeating;
    instruction = 'Repeat the sequence';
    notifyListeners();
  }

  Future<void> tapColor(SequenceColor color) async {
    if (!canTapColors) {
      return;
    }

    playerSequence = [...playerSequence, color];
    final index = playerSequence.length - 1;

    if (playerSequence[index] != targetSequence[index]) {
      await _handleWrongTap();
      return;
    }

    if (playerSequence.length == targetSequence.length) {
      await _handleCorrectSequence();
    } else {
      notifyListeners();
    }
  }

  Future<void> _handleWrongTap() async {
    wrongAnswers += 1;
    currentStreak = 0;
    lives -= 1;
    phase = ColorSequencePhase.feedback;
    feedbackMessage = 'Wrong color';
    instruction = 'Wrong color';
    await soundService.playWrong();
    _phaseTimer?.cancel();

    if (lives <= 0) {
      _offerGameOverOrSecondLife();
      return;
    }

    _phaseTimer = Timer(const Duration(milliseconds: 500), () {
      if (!isRoundComplete && !isGameplayPaused) {
        unawaited(_replayCurrentSequence());
      }
    });
    notifyListeners();
  }

  void _offerGameOverOrSecondLife() {
    if (!secondLife.secondLifeUsed) {
      secondLife.pauseForSecondLifeOffer();
      notifyListeners();
      return;
    }
    unawaited(endGameFinal());
  }

  Future<void> _handleCorrectSequence() async {
    correctAnswers += 1;
    currentStreak += 1;
    score += ScoreUtils.correctAnswerPoints;
    if (currentStreak % ScoreUtils.streakBonusEvery == 0) {
      score += ScoreUtils.streakBonusPoints;
    }
    level += 1;

    phase = ColorSequencePhase.feedback;
    feedbackMessage = 'Correct!';
    instruction = 'Correct!';
    await soundService.playCorrect();
    notifyListeners();

    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 450), () {
      if (!isRoundComplete && !isGameplayPaused) {
        unawaited(_startRound());
      }
    });
  }

  Future<void> resumeFromSecondLifeReward() async {
    secondLife.markSecondLifeUsed();
    lives = 1;
    feedbackMessage = null;
    await _replayCurrentSequence();
    notifyListeners();
  }

  Future<void> _replayCurrentSequence() async {
    _phaseTimer?.cancel();
    playerSequence = [];
    highlightedIndex = null;
    phase = ColorSequencePhase.watching;
    instruction = 'Watch the pattern again';
    notifyListeners();

    for (var i = 0; i < targetSequence.length; i++) {
      if (isRoundComplete || isGameplayPaused) {
        return;
      }
      highlightedIndex = i;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 550));
      highlightedIndex = null;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    if (isRoundComplete) {
      return;
    }

    phase = ColorSequencePhase.repeating;
    instruction = 'Repeat the sequence';
    notifyListeners();
  }

  Future<void> endGameFinal() async {
    if (isRoundComplete) {
      return;
    }

    secondLife.endGameFinal();
    isRoundComplete = true;
    _phaseTimer?.cancel();
    final previousBest = bestScore;
    bestScore = await storage.saveHighScoreIfHigher(
      GameType.colorSequence,
      _storage,
      score,
    );
    result = ScoreModel(
      gameType: GameType.colorSequence,
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
    phase = ColorSequencePhase.idle;
    instruction = 'Watch the pattern';
    feedbackMessage = null;
    targetSequence = [];
    playerSequence = [];
    isLoading = false;
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }
}
