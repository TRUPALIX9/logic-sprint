import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
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
    required this.difficulty,
    Random? random,
  }) : random = random ?? Random();

  final LocalStorageService storage;
  final SoundService soundService;
  final DifficultyLevel difficulty;
  final Random random;

  static const List<SequenceColor> palette = SequenceColor.values;

  Timer? _roundTimer;
  Timer? _phaseTimer;

  int secondsRemaining = ScoreUtils.roundLengthSeconds;
  int score = 0;
  int bestScore = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int currentStreak = 0;
  int completedRounds = 0;
  int sequenceLength = 3;
  int? highlightedIndex;
  bool isLoading = true;
  bool isRoundComplete = false;
  ColorSequencePhase phase = ColorSequencePhase.idle;
  String instruction = 'Watch the pattern';
  String? feedbackMessage;
  List<SequenceColor> targetSequence = [];
  List<SequenceColor> playerSequence = [];
  ScoreModel? result;

  double get progress =>
      secondsRemaining / ScoreUtils.roundLengthSeconds.clamp(1, 999);

  double get accuracy => ScoreUtils.accuracyPercentage(
    correctAnswers: correctAnswers,
    wrongAnswers: wrongAnswers,
  );

  int get roundNumber => completedRounds + 1;

  bool get canTapColors =>
      phase == ColorSequencePhase.repeating && !isRoundComplete;

  Future<void> initialize() async {
    bestScore = storage.getHighScore(GameType.colorSequence, difficulty);
    sequenceLength = _startingSequenceLength;
    isLoading = false;
    notifyListeners();
    _startTimer();
    await _startRound();
  }

  static int startingSequenceLengthFor(DifficultyLevel level) {
    return switch (level) {
      DifficultyLevel.easy => 3,
      DifficultyLevel.medium => 4,
      DifficultyLevel.hard => 5,
    };
  }

  int get _startingSequenceLength => startingSequenceLengthFor(difficulty);

  void _startTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  List<SequenceColor> generateSequence(int length) {
    return List<SequenceColor>.generate(
      length,
      (_) => palette[random.nextInt(palette.length)],
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

    for (var i = 0; i < targetSequence.length; i++) {
      if (isRoundComplete) {
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
    phase = ColorSequencePhase.feedback;
    feedbackMessage = 'Try again';
    instruction = 'Try again';
    await soundService.playWrong();
    notifyListeners();

    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 450), () {
      if (!isRoundComplete) {
        unawaited(_startRound());
      }
    });
  }

  Future<void> _handleCorrectSequence() async {
    correctAnswers += 1;
    currentStreak += 1;
    completedRounds += 1;
    score += ScoreUtils.correctAnswerPoints;
    if (currentStreak % ScoreUtils.streakBonusEvery == 0) {
      score += ScoreUtils.streakBonusPoints;
    }

    if (completedRounds % 2 == 0) {
      sequenceLength += 1;
    }

    phase = ColorSequencePhase.feedback;
    feedbackMessage = 'Correct!';
    instruction = 'Correct!';
    await soundService.playCorrect();
    notifyListeners();

    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 450), () {
      if (!isRoundComplete) {
        unawaited(_startRound());
      }
    });
  }

  Future<void> finishRound() async {
    if (isRoundComplete) {
      return;
    }

    isRoundComplete = true;
    _roundTimer?.cancel();
    _phaseTimer?.cancel();
    final previousBest = bestScore;
    bestScore = await storage.saveHighScoreIfHigher(
      GameType.colorSequence,
      difficulty,
      score,
    );
    result = ScoreModel(
      gameType: GameType.colorSequence,
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

  @override
  void dispose() {
    _roundTimer?.cancel();
    _phaseTimer?.cancel();
    super.dispose();
  }
}
