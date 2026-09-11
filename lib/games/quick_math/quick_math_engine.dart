import 'dart:async';
import 'dart:math';

import '../../models/game.dart';
import '../round_engine.dart';

enum MathOp {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const MathOp(this.symbol);
  final String symbol;
}

class MathProblem {
  const MathProblem(this.a, this.op, this.b, this.answer, this.options);

  final int a;
  final MathOp op;
  final int b;
  final int answer;

  /// Four distinct non-negative choices, one of them [answer].
  final List<int> options;

  String get text => '$a ${op.symbol} $b';
}

/// Quick Math: endless problems that get harder every 10 solved; one wrong
/// answer ends the run.
class QuickMathEngine extends RoundEngine {
  QuickMathEngine({
    required super.difficulty,
    super.previousBest,
    super.feedback,
    super.random,
  }) : super(game: GameId.quickMath) {
    problem = generate(difficulty, random);
  }

  static const _feedbackPause = Duration(milliseconds: 280);

  /// Problems per level; each level widens the numbers.
  static const problemsPerLevel = 10;

  late MathProblem problem;
  int number = 1;

  /// The option just tapped; non-null while its feedback shows.
  int? picked;
  Timer? _next;

  int get level => (number - 1) ~/ problemsPerLevel;

  bool get locked => picked != null || !isPlaying;

  /// Operations for [difficulty] at [level]: Easy adds × from level 2 and
  /// Medium adds ÷ from level 2.
  static List<MathOp> opsFor(Difficulty difficulty, [int level = 0]) =>
      switch (difficulty) {
        Difficulty.easy => [
          MathOp.add,
          MathOp.subtract,
          if (level >= 2) MathOp.multiply,
        ],
        Difficulty.medium => [
          MathOp.add,
          MathOp.subtract,
          MathOp.multiply,
          if (level >= 2) MathOp.divide,
        ],
        Difficulty.hard => MathOp.values,
      };

  static MathProblem generate(
    Difficulty difficulty,
    Random random, [
    int level = 0,
  ]) {
    int between(int lo, int hi) => lo + random.nextInt(hi - lo + 1);
    final ops = opsFor(difficulty, level);
    final op = ops[random.nextInt(ops.length)];
    final (lo, hi) = switch (difficulty) {
      Difficulty.easy => (1, 20),
      Difficulty.medium => (5, 50),
      Difficulty.hard => (10, 99),
    };
    // Numbers grow by half the base range per level, up to 3×.
    final grow = 1 + 0.5 * min(level, 4);
    final top = (hi * grow).round();
    final step = min(level, 6);
    final hard = difficulty == Difficulty.hard;

    final (int a, int b, int answer) = switch (op) {
      MathOp.add => () {
        final a = between(lo, top), b = between(lo, top);
        return (a, b, a + b);
      }(),
      MathOp.subtract => () {
        final x = between(lo, top), y = between(lo, top);
        return (max(x, y), min(x, y), (x - y).abs());
      }(),
      MathOp.multiply => () {
        final a = between(2, (hard ? 15 : 12) + step * 2);
        final b = between(2, (hard ? 12 : 9) + step);
        return (a, b, a * b);
      }(),
      MathOp.divide => () {
        final b = between(2, 12 + step), answer = between(2, 12 + step);
        return (b * answer, b, answer);
      }(),
    };
    return MathProblem(a, op, b, answer, _options(answer, random));
  }

  static List<int> _options(int answer, Random random) {
    final offsets = [1, 2, 3, 5, 10, -1, -2, -3, -5, -10]..shuffle(random);
    final choices = <int>{answer};
    for (final offset in offsets) {
      if (choices.length == 4) {
        break;
      }
      if (answer + offset >= 0) {
        choices.add(answer + offset);
      }
    }
    return choices.toList()..shuffle(random);
  }

  void _nextProblem() {
    picked = null;
    number++;
    problem = generate(difficulty, random, level);
    notify();
  }

  void answer(int value) {
    if (locked) {
      return;
    }
    picked = value;
    if (value == problem.answer) {
      scoreCorrect();
      _next = Timer(_feedbackPause, () {
        if (isPlaying) {
          _nextProblem();
        }
      });
    } else {
      // Keeps [picked] so the wrong pick and the right answer stay visible.
      fail();
    }
  }

  @override
  void onDown() => _next?.cancel();

  @override
  void onRevive() => _nextProblem();

  @override
  void onFinish() => _next?.cancel();

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }
}
