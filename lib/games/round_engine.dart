import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../models/game.dart';
import '../models/round_result.dart';

/// Haptic/sound hooks a round fires. Implemented by AppState.
abstract interface class RoundFeedback {
  void tap();
  void correct();
  void wrong();
}

/// A 30-second round. Owns the clock (never shown on screen), score, the
/// hidden streak bonus, and the final [RoundResult]. Game engines subclass
/// this and call [scoreCorrect] / [scoreWrong].
abstract class RoundEngine extends ChangeNotifier {
  RoundEngine({
    required this.game,
    required this.difficulty,
    this.previousBest = 0,
    this.feedback,
    Random? random,
  }) : random = random ?? Random();

  final GameId game;
  final Difficulty difficulty;
  final int previousBest;
  final RoundFeedback? feedback;
  final Random random;

  int score = 0;
  int correct = 0;
  int wrong = 0;
  int _streak = 0;
  Timer? _clock;
  bool _started = false;
  bool _disposed = false;
  RoundResult? _result;

  bool get isFinished => _result != null;
  RoundResult? get result => _result;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _clock = Timer(const Duration(seconds: AppConfig.roundSeconds), finish);
    onStart();
  }

  /// Hook for engines that run their own loop or playback.
  @protected
  void onStart() {}

  /// Hook to cancel engine timers before the result is built.
  @protected
  void onFinish() {}

  @protected
  void scoreCorrect([int points = AppConfig.pointsPerCorrect]) {
    correct++;
    _streak++;
    score += points;
    if (_streak % AppConfig.streakBonusEvery == 0) {
      score += AppConfig.streakBonusPoints;
    }
    feedback?.correct();
    notify();
  }

  @protected
  void scoreWrong({int penalty = 0}) {
    wrong++;
    _streak = 0;
    score = max(0, score - penalty);
    feedback?.wrong();
    notify();
  }

  @protected
  void addBonus(int points) {
    score += points;
    notify();
  }

  void finish() {
    if (isFinished) {
      return;
    }
    _clock?.cancel();
    onFinish();
    _result = RoundResult(
      game: game,
      difficulty: difficulty,
      score: score,
      correct: correct,
      wrong: wrong,
      previousBest: previousBest,
    );
    notify();
  }

  /// notifyListeners that is safe after dispose (late timer callbacks).
  @protected
  void notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    super.dispose();
  }
}
