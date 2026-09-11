import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../round_screen.dart';
import 'guess_color_board.dart';
import 'guess_color_engine.dart';

class GuessColorScreen extends StatelessWidget {
  const GuessColorScreen({super.key, required this.difficulty});

  /// Passed through to the run; the game itself has one ramping mode.
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
      builder: (context, engine) => GuessColorBoard(engine: engine),
    );
  }
}
