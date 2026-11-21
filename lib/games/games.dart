import 'package:flutter/material.dart';

import '../models/game.dart';
import 'angle_sense/angle_sense_screen.dart';
import 'guess_color/guess_color_screen.dart';
import 'line_split/line_split_screen.dart';
import 'memory_lane/memory_lane_screen.dart';
import 'quick_math/quick_math_screen.dart';
import 'rocket_launch/rocket_launch_screen.dart';

Route<void> gameRoute(GameId game, Difficulty difficulty) =>
    MaterialPageRoute<void>(
      builder: (_) => switch (game) {
        GameId.rocketLaunch => RocketLaunchScreen(difficulty: difficulty),
        GameId.memoryLane => MemoryLaneScreen(difficulty: difficulty),
        GameId.quickMath => QuickMathScreen(difficulty: difficulty),
        GameId.guessColor => GuessColorScreen(difficulty: difficulty),
        GameId.angleSense => AngleSenseScreen(difficulty: difficulty),
        GameId.lineSplit => LineSplitScreen(difficulty: difficulty),
      },
    );
