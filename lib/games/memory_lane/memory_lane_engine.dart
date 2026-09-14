import 'dart:async';

import '../../models/game.dart';
import '../round_engine.dart';

enum MemoryPhase { watch, repeat }

/// Memory Lane: watch tiles light up in order, then tap them back. Every
/// clean repeat levels up and adds one tile; one miss ends the run.
class MemoryLaneEngine extends RoundEngine {
  MemoryLaneEngine({
    required super.difficulty,
    super.previousBest,
    super.feedback,
    super.random,
  }) : gridSize = gridSizeFor(difficulty),
       super(game: GameId.memoryLane) {
    _sequence = _generate(startLengthFor(difficulty));
  }

  static const _leadIn = Duration(milliseconds: 600);
  static const _litFor = Duration(milliseconds: 450);
  static const _gap = Duration(milliseconds: 150);
  static const _levelPause = Duration(milliseconds: 800);
  static const _flash = Duration(milliseconds: 250);
  static const levelBonus = 20;

  final int gridSize;
  late List<int> _sequence;
  MemoryPhase phase = MemoryPhase.watch;
  int level = 1;

  /// Tile lit during playback; null between tiles.
  int? litTile;

  /// Correct taps so far in the current repeat.
  int stepsDone = 0;

  /// Tiles just tapped; non-null while their feedback shows. [wrongTile]
  /// stays until the run is revived.
  int? correctTile;
  int? wrongTile;

  /// True between a completed repeat and the next playback.
  bool _waiting = false;

  /// Set when a pause cut into playback: resuming replays from the start.
  bool _replayOnResume = false;
  PausableTimer? _step;
  Timer? _flashTimer;

  int get tileCount => gridSize * gridSize;
  List<int> get sequence => List.unmodifiable(_sequence);
  int get sequenceLength => _sequence.length;
  bool get canTap => phase == MemoryPhase.repeat && !_waiting && isPlaying;

  static int gridSizeFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 3,
    Difficulty.medium => 4,
    Difficulty.hard => 5,
  };

  static int startLengthFor(Difficulty difficulty) => gridSizeFor(difficulty);

  /// Random tiles with no immediate repeats, so every step reads as a move.
  List<int> _generate(int length) {
    final tiles = <int>[];
    while (tiles.length < length) {
      final tile = random.nextInt(tileCount);
      if (tiles.isEmpty || tiles.last != tile) {
        tiles.add(tile);
      }
    }
    return tiles;
  }

  @override
  void onStart() => _play();

  void _play() {
    _waiting = false;
    phase = MemoryPhase.watch;
    stepsDone = 0;
    litTile = null;
    correctTile = null;
    wrongTile = null;
    notify();
    _step = PausableTimer(_leadIn, () => _show(0));
  }

  void _show(int index) {
    litTile = _sequence[index];
    notify();
    _step = PausableTimer(_litFor, () {
      litTile = null;
      if (index + 1 < _sequence.length) {
        notify();
        _step = PausableTimer(_gap, () => _show(index + 1));
      } else {
        phase = MemoryPhase.repeat;
        notify();
      }
    });
  }

  void tap(int index) {
    if (!canTap) {
      return;
    }
    if (index == _sequence[stepsDone]) {
      stepsDone++;
      _flashCorrect(index);
      scoreCorrect();
      if (stepsDone == _sequence.length) {
        addBonus(levelBonus);
        level++;
        _waiting = true;
        _step = PausableTimer(_levelPause, () {
          _sequence = _generate(_sequence.length + 1);
          _play();
        });
      }
    } else {
      wrongTile = index;
      fail();
    }
  }

  void _flashCorrect(int index) {
    correctTile = index;
    _flashTimer?.cancel();
    _flashTimer = Timer(_flash, () {
      correctTile = null;
      notify();
    });
  }

  void _cancelTimers() {
    _step?.cancel();
    _flashTimer?.cancel();
    litTile = null;
    correctTile = null;
  }

  /// Paused mid-playback: stop it and replay the pattern from the start on
  /// resume (fair after a break). Paused while repeating: taps done so far
  /// stay, and a pending level-up delay keeps its remaining time.
  @override
  void onPause() {
    _flashTimer?.cancel();
    correctTile = null;
    if (phase == MemoryPhase.watch) {
      _step?.cancel();
      litTile = null;
      _replayOnResume = true;
    } else {
      _step?.pause();
    }
  }

  @override
  void onResume() {
    if (_replayOnResume) {
      _replayOnResume = false;
      _play();
    } else {
      _step?.resume();
    }
  }

  @override
  void onDown() => _cancelTimers();

  /// Another try at the same pattern, from a fresh playback. Works on every
  /// revive: [_play] resets the phase, taps and feedback.
  @override
  void onRevive() => _play();

  @override
  void onFinish() => _cancelTimers();

  @override
  void dispose() {
    _step?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }
}
