import 'dart:async';

import '../../models/game.dart';
import '../round_engine.dart';

enum MemoryPhase { watch, repeat }

/// Memory Lane: watch tiles light up in order, then tap them back. A clean
/// repeat levels up and adds one tile; a miss replays a fresh sequence.
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
  static const _retryPause = Duration(milliseconds: 600);
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

  /// Tiles just tapped; non-null while their feedback shows.
  int? correctTile;
  int? wrongTile;

  /// True between a finished/failed repeat and the next playback.
  bool _waiting = false;
  Timer? _step;
  Timer? _flashTimer;

  int get tileCount => gridSize * gridSize;
  List<int> get sequence => List.unmodifiable(_sequence);
  int get sequenceLength => _sequence.length;
  bool get canTap => phase == MemoryPhase.repeat && !_waiting && !isFinished;

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
    _step = Timer(_leadIn, () => _show(0));
  }

  void _show(int index) {
    litTile = _sequence[index];
    notify();
    _step = Timer(_litFor, () {
      litTile = null;
      if (index + 1 < _sequence.length) {
        notify();
        _step = Timer(_gap, () => _show(index + 1));
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
        _replayAfter(_levelPause, _sequence.length + 1);
      }
    } else {
      wrongTile = index;
      scoreWrong();
      _replayAfter(_retryPause, _sequence.length);
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

  void _replayAfter(Duration pause, int length) {
    _waiting = true;
    _step = Timer(pause, () {
      _sequence = _generate(length);
      _play();
    });
  }

  void _cancelTimers() {
    _step?.cancel();
    _flashTimer?.cancel();
  }

  @override
  void onFinish() {
    _cancelTimers();
    litTile = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
