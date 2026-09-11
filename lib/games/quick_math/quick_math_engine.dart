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

/// Quick Math: tap the right answer; a new problem follows every tap.
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

  late MathProblem problem;
  int number = 1;

  /// The option just tapped; non-null while its feedback shows.
  int? picked;
  Timer? _next;

  bool get locked => picked != null || isFinished;

  static List<MathOp> opsFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => const [MathOp.add, MathOp.subtract],
    Difficulty.medium => const [MathOp.add, MathOp.subtract, MathOp.multiply],
    Difficulty.hard => MathOp.values,
  };

  static MathProblem generate(Difficulty difficulty, Random random) {
    int between(int lo, int hi) => lo + random.nextInt(hi - lo + 1);
    final ops = opsFor(difficulty);
    final op = ops[random.nextInt(ops.length)];
    final (lo, hi) = switch (difficulty) {
      Difficulty.easy => (1, 20),
      Difficulty.medium => (5, 50),
      Difficulty.hard => (10, 99),
    };
    final hard = difficulty == Difficulty.hard;

    final (int a, int b, int answer) = switch (op) {
      MathOp.add => () {
        final a = between(lo, hi), b = between(lo, hi);
        return (a, b, a + b);
      }(),
      MathOp.subtract => () {
        final x = between(lo, hi), y = between(lo, hi);
        return (max(x, y), min(x, y), (x - y).abs());
      }(),
      MathOp.multiply => () {
        final a = between(2, hard ? 15 : 12), b = between(2, hard ? 12 : 9);
        return (a, b, a * b);
      }(),
      MathOp.divide => () {
        final b = between(2, 12), answer = between(2, 12);
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

  void answer(int value) {
    if (locked) {
      return;
    }
    picked = value;
    if (value == problem.answer) {
      scoreCorrect();
    } else {
      scoreWrong();
    }
    _next = Timer(_feedbackPause, () {
      if (isFinished) {
        return;
      }
      picked = null;
      number++;
      problem = generate(difficulty, random);
      notify();
    });
  }

  @override
  void onFinish() => _next?.cancel();

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }
}
