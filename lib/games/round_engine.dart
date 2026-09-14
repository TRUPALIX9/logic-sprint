import 'dart:async';
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

/// Where a run stands. [paused] is a [playing] run on hold (app in the
/// background or the player tapped pause): nothing moves and the clock is
/// stopped until [RoundEngine.resume]. After a mistake the run is [down]:
/// the host may offer a revive (a rewarded ad or a heart) before it is
/// [over].
enum RunState { ready, playing, paused, down, over }

/// An endless run: plays until a mistake, can be revived up to
/// [AppConfig.maxRevivesPerRun] times, and records how long it lasted (time
/// spent [RunState.paused] or [RunState.down] doesn't count). Game engines
/// subclass this and call [scoreCorrect] and [fail].
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
  int _revives = 0;
  bool _disposed = false;
  RunState _state = RunState.ready;
  RoundResult? _result;

  // From package:clock so fake_async can drive it in tests.
  final Stopwatch _stopwatch = clock.stopwatch();

  RunState get state => _state;

  /// True only while the run is live: false when paused, down or over.
  bool get isPlaying => _state == RunState.playing;
  bool get isPaused => _state == RunState.paused;
  bool get isFinished => _state == RunState.over;

  /// Down with revives left this run.
  bool get canRevive =>
      _state == RunState.down && _revives < AppConfig.maxRevivesPerRun;

  /// How many times this run has been revived.
  int get revives => _revives;
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

  /// Freeze timers and playback, keeping what's left of them.
  @protected
  void onPause() {}

  /// Continue exactly where [onPause] left off.
  @protected
  void onResume() {}

  /// Pause everything: the run may still be revived.
  @protected
  void onDown() {}

  /// Resume after a revive (e.g. clear the danger, replay the level). May be
  /// called several times in one run.
  @protected
  void onRevive() {}

  /// Cancel timers before the result is built.
  @protected
  void onFinish() {}

  /// Puts a [RunState.playing] run on hold; a no-op otherwise.
  void pause() {
    if (!isPlaying) {
      return;
    }
    _stopwatch.stop();
    _state = RunState.paused;
    onPause();
    notify();
  }

  /// Continues a [RunState.paused] run; a no-op otherwise.
  void resume() {
    if (!isPaused) {
      return;
    }
    _state = RunState.playing;
    _stopwatch.start();
    onResume();
    notify();
  }

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

  /// A mistake: the run goes [RunState.down] until it is revived or
  /// finished.
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

  /// Continues a [RunState.down] run (after a rewarded ad or a heart), while
  /// [canRevive].
  void revive() {
    if (!canRevive) {
      return;
    }
    _revives++;
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

/// A one-shot [Timer] that can be put on hold: [pause] keeps the time left
/// and [resume] waits out only that. Uses package:clock, so fake_async
/// drives it in tests.
class PausableTimer {
  PausableTimer(Duration duration, this._callback) : _left = duration {
    _run();
  }

  final VoidCallback _callback;
  final Stopwatch _watch = clock.stopwatch();
  Duration _left;
  Timer? _timer;
  bool _done = false;

  /// Neither fired nor cancelled (it may be paused).
  bool get isActive => !_done;
  bool get isPaused => !_done && _timer == null;

  /// Time until it fires, not counting any time on hold.
  Duration get remaining {
    if (_done) {
      return Duration.zero;
    }
    final left = _timer == null ? _left : _left - _watch.elapsed;
    return left < Duration.zero ? Duration.zero : left;
  }

  void _run() {
    _watch
      ..reset()
      ..start();
    _timer = Timer(_left, () {
      _done = true;
      _timer = null;
      _watch.stop();
      _callback();
    });
  }

  void pause() {
    if (_done || _timer == null) {
      return;
    }
    _left = remaining;
    _timer!.cancel();
    _timer = null;
    _watch.stop();
  }

  void resume() {
    if (isPaused) {
      _run();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _watch.stop();
    _done = true;
  }
}
