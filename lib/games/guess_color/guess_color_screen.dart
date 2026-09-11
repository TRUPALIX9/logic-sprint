import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import '../round_screen.dart';
import 'guess_color_engine.dart';

class GuessColorScreen extends StatelessWidget {
  const GuessColorScreen({super.key, required this.difficulty});

  /// Passed through to the round; the game itself has one ramping mode.
  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return RoundScreen<GuessColorEngine>(
      game: GameId.guessColor,
      difficulty: difficulty,
      createEngine: (feedback, best) => GuessColorEngine(
        difficulty: difficulty,
        previousBest: best,
        feedback: feedback,
      ),
      builder: (context, engine) => _GuessColorBody(engine),
    );
  }
}

class _GuessColorBody extends StatelessWidget {
  const _GuessColorBody(this.engine);

  final GuessColorEngine engine;

  @override
  Widget build(BuildContext context) {
    final item = engine.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: ChamferBox(
              cut: Cut.lg,
              color: LS.well,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                children: [
                  const MonoLabel('Tap the ink color — not the word'),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: DisplayText(
                          item.word.label,
                          size: 88,
                          color: item.ink.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            flex: 3,
            child: _AnswerGrid(engine: engine, colors: item.buttons),
          ),
        ],
      ),
    );
  }
}

/// Two columns filling the lower area: 2 rows for 4 colors, 3 for 6.
class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({required this.engine, required this.colors});

  static const _gap = 12.0;

  final GuessColorEngine engine;
  final List<InkColor> colors;

  @override
  Widget build(BuildContext context) {
    final rows = (colors.length / 2).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: _gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _AnswerButton(engine: engine, color: colors[row * 2]),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: _AnswerButton(
                    engine: engine,
                    color: colors[row * 2 + 1],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.engine, required this.color});

  final GuessColorEngine engine;
  final InkColor color;

  @override
  Widget build(BuildContext context) {
    final picked = engine.picked;
    final isAnswer = color == engine.item.ink;
    // After a tap: the pick turns teal or coral; a wrong pick also reveals
    // the right answer in teal.
    final Color? state = picked == null
        ? null
        : isAnswer
        ? LS.teal
        : picked == color
        ? LS.coral
        : null;
    return ChamferBox(
      color:
          state?.withValues(alpha: 0.14) ?? color.color.withValues(alpha: 0.08),
      borderColor: state ?? color.color.withValues(alpha: 0.4),
      onTap: engine.locked ? null : () => engine.pick(color),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: chamfer(Cut.sm),
              color: color.color,
            ),
            child: const SizedBox(width: 28, height: 28),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DisplayText(color.label, size: 20, color: color.color),
            ),
          ),
        ],
      ),
    );
  }
}
