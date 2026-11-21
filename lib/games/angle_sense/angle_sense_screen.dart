import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../round_screen.dart';
import 'angle_sense_board.dart';
import 'angle_sense_engine.dart';

class AngleSenseScreen extends StatelessWidget {
  const AngleSenseScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return RoundScreen<AngleSenseEngine>(
      game: GameId.angleSense,
      difficulty: difficulty,
      createEngine: (feedback, best) => AngleSenseEngine(
        difficulty: difficulty,
        previousBest: best,
        feedback: feedback,
      ),
      builder: (context, engine) => AngleSenseBoard(engine: engine),
    );
  }
}
