import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import '../round_screen.dart';
import 'quick_math_engine.dart';

class QuickMathScreen extends StatelessWidget {
  const QuickMathScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return RoundScreen<QuickMathEngine>(
      game: GameId.quickMath,
      difficulty: difficulty,
      createEngine: (feedback, best) => QuickMathEngine(
        difficulty: difficulty,
        previousBest: best,
        feedback: feedback,
      ),
      builder: (context, engine) => _QuickMathBody(engine),
    );
  }
}

/// Problem on top, 2×2 answers below; both halves stretch to fill the screen.
class _QuickMathBody extends StatelessWidget {
  const _QuickMathBody(this.engine);

  final QuickMathEngine engine;

  @override
  Widget build(BuildContext context) {
    final options = engine.problem.options;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: ChamferBox(
              cut: Cut.lg,
              color: LS.well,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      child: DisplayText(engine.problem.text, size: 88),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '= ?',
                      style: LSText.mono(26, color: LS.dim, spacing: 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _AnswerRow(
                    engine: engine,
                    values: options.sublist(0, 2),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _AnswerRow(engine: engine, values: options.sublist(2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.engine, required this.values});

  final QuickMathEngine engine;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _AnswerButton(engine: engine, value: values[0]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AnswerButton(engine: engine, value: values[1]),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.engine, required this.value});

  final QuickMathEngine engine;
  final int value;

  @override
  Widget build(BuildContext context) {
    final picked = engine.picked;
    final isAnswer = value == engine.problem.answer;
    // After a tap: the pick turns teal or coral; a wrong pick also reveals
    // the right answer in teal.
    final Color? state = picked == null
        ? null
        : isAnswer
        ? LS.teal
        : picked == value
        ? LS.coral
        : null;
    return ChamferBox(
      color: state?.withValues(alpha: 0.14) ?? LS.surface,
      borderColor: state ?? LS.line,
      onTap: engine.locked ? null : () => engine.answer(value),
      child: Center(
        child: FittedBox(
          child: DisplayText('$value', size: 44, color: state ?? LS.text),
        ),
      ),
    );
  }
}
