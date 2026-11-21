import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../round_screen.dart';
import 'line_split_board.dart';
import 'line_split_engine.dart';

class LineSplitScreen extends StatelessWidget {
  const LineSplitScreen({super.key, required this.difficulty});

  /// Passed through to the run; the game itself has one ramping mode.
  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return RoundScreen<LineSplitEngine>(
      game: GameId.lineSplit,
      difficulty: difficulty,
      createEngine: (feedback, best) => LineSplitEngine(
        difficulty: difficulty,
        previousBest: best,
        feedback: feedback,
      ),
      builder: (context, engine) => LineSplitBoard(engine: engine),
    );
  }
}
