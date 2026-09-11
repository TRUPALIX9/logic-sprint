import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../models/game.dart';
import '../models/round_result.dart';

/// Haptic/sound hooks a run fires. Implemented by AppState.
abstract interface class RoundFeedback {
  void tap();
  void correct();
  void wrong();
}

/// Where a run stands. After a mistake the run is [down]: the host may offer
/// one revive (a rewarded ad) before it is [over].
enum RunState { ready, playing, down, over }

/// An endless run: plays until the first mistake, can be revived once, and
/// records how long it lasted (time spent [down] doesn't count). Game
/// engines subclass this and call [scoreCorrect] and [fail].
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
  int _streak = 0;
  bool _revived = false;
  bool _disposed = false;
  RunState _state = RunState.ready;
  RoundResult? _result;

  // From package:clock so fake_async can drive it in tests.
  final Stopwatch _stopwatch = clock.stopwatch();

  RunState get state => _state;
  bool get isPlaying => _state == RunState.playing;
  bool get isFinished => _state == RunState.over;
  bool get canRevive => _state == RunState.down && !_revived;
  bool get revived => _revived;
  Duration get elapsed => _stopwatch.elapsed;
  RoundResult? get result => _result;

  void start() {
    if (_state != RunState.ready) {
      return;
    }
    _state = RunState.playing;
    _stopwatch.start();
    onStart();
    notify();
  }

  /// Start loops, timers or playback.
  @protected
  void onStart() {}

  /// Pause everything: the run may still be revived.
  @protected
  void onDown() {}

  /// Resume after a revive (e.g. clear the danger, replay the level).
  @protected
  void onRevive() {}

  /// Cancel timers before the result is built.
  @protected
  void onFinish() {}

  @protected
  void scoreCorrect([int points = AppConfig.pointsPerCorrect]) {
    if (!isPlaying) {
      return;
    }
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
  void addBonus(int points) {
    score += points;
    notify();
  }

  /// A mistake: the run goes [down] until it is revived or finished.
  @protected
  void fail() {
    if (!isPlaying) {
      return;
    }
    _streak = 0;
    _stopwatch.stop();
    _state = RunState.down;
    feedback?.wrong();
    onDown();
    notify();
  }

  /// Continues a [down] run once (after the rewarded ad).
  void revive() {
    if (!canRevive) {
      return;
    }
    _revived = true;
    _state = RunState.playing;
    _stopwatch.start();
    onRevive();
    notify();
  }

  /// Ends the run and builds the [result].
  void finish() {
    if (_state == RunState.over) {
      return;
    }
    _stopwatch.stop();
    onFinish();
    _state = RunState.over;
    _result = RoundResult(
      game: game,
      difficulty: difficulty,
      score: score,
      correct: correct,
      duration: _stopwatch.elapsed,
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
    _stopwatch.stop();
    super.dispose();
  }
}
