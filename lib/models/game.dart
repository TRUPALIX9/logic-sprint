import 'package:flutter/material.dart';

import '../core/theme.dart';

enum Difficulty {
  easy,
  medium,
  hard;

  String get label => name.toUpperCase();
}

/// The four games. [name] doubles as the storage and leaderboard key.
enum GameId {
  rocketLaunch,
  memoryLane,
  quickMath,
  guessColor;

  /// Difficulty that ramp games (no Easy/Medium/Hard) play and store
  /// their scores under.
  static const rampDifficulty = Difficulty.medium;

  static GameId? tryParse(String value) {
    for (final game in values) {
      if (game.name == value) {
        return game;
      }
    }
    return null;
  }

  /// Memory Lane and Quick Math offer Easy/Medium/Hard; the other two play
  /// one mode that ramps up during the round.
  bool get hasDifficulty => this == memoryLane || this == quickMath;

  String get title => switch (this) {
    rocketLaunch => 'Rocket Launch',
    memoryLane => 'Memory Lane',
    quickMath => 'Quick Math',
    guessColor => 'Guess Color',
  };

  /// "Quick Math · HARD", or just the title for ramp games.
  String titleWith(Difficulty difficulty) =>
      hasDifficulty ? '$title · ${difficulty.label}' : title;

  String get skill => switch (this) {
    rocketLaunch => 'Reflex',
    memoryLane => 'Memory',
    quickMath => 'Arithmetic',
    guessColor => 'Focus',
  };

  Color get accent => switch (this) {
    rocketLaunch => LS.blue,
    memoryLane => LS.aqua,
    quickMath => LS.teal,
    guessColor => LS.violet,
  };

  IconData get icon => switch (this) {
    rocketLaunch => Icons.rocket_launch_outlined,
    memoryLane => Icons.grid_view_rounded,
    quickMath => Icons.calculate_outlined,
    guessColor => Icons.palette_outlined,
  };

  String get rules => switch (this) {
    rocketLaunch =>
      'Asteroids rain down. Touch and drag anywhere on the field to steer around them.',
    memoryLane =>
      'Tiles light up one at a time. Tap them back in the same order — every level adds one more tile to remember.',
    quickMath =>
      'Solve each problem and tap the right answer. Keep a clean streak for bonus points.',
    guessColor =>
      'A color word appears in a different ink. Tap the ink color, not the word.',
  };

  /// How a ramp game escalates; null for games with difficulty levels.
  String? get rampNote => switch (this) {
    rocketLaunch => 'Gets faster as you go',
    guessColor => 'Gets trickier as you go',
    memoryLane || quickMath => null,
  };

  /// What each difficulty changes. Empty for ramp games.
  String detail(Difficulty difficulty) => switch ((this, difficulty)) {
    (memoryLane, Difficulty.easy) => '3×3 grid',
    (memoryLane, Difficulty.medium) => '4×4 grid',
    (memoryLane, Difficulty.hard) => '5×5 grid',
    (quickMath, Difficulty.easy) => '+ and −',
    (quickMath, Difficulty.medium) => '+ − ×',
    (quickMath, Difficulty.hard) => '+ − × ÷',
    _ => '',
  };
}
