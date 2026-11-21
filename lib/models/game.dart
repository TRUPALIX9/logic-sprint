import 'package:flutter/material.dart';

import '../core/theme.dart';

enum Difficulty {
  easy,
  medium,
  hard;

  String get label => name.toUpperCase();
}

/// The games. [name] doubles as the storage and leaderboard key, so new
/// games are always added last.
enum GameId {
  rocketLaunch,
  memoryLane,
  quickMath,
  guessColor,
  angleSense,
  lineSplit;

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
  bool get hasDifficulty =>
      this == memoryLane || this == quickMath || this == angleSense;

  /// Memory Lane and Quick Math care how long a run took: its time is shown
  /// and a faster run wins a tie. The other two are about how far you get.
  bool get tracksTime => this == memoryLane || this == quickMath;

  String get title => switch (this) {
    rocketLaunch => 'Rocket Launch',
    memoryLane => 'Memory Lane',
    quickMath => 'Quick Math',
    guessColor => 'Guess Color',
    angleSense => 'Angle Sense',
    lineSplit => 'Line Split',
  };

  /// "Quick Math · HARD", or just the title for ramp games.
  String titleWith(Difficulty difficulty) =>
      hasDifficulty ? '$title · ${difficulty.label}' : title;

  String get skill => switch (this) {
    rocketLaunch => 'Reflex',
    memoryLane => 'Memory',
    quickMath => 'Arithmetic',
    guessColor => 'Focus',
    angleSense => 'Spatial',
    lineSplit => 'Estimation',
  };

  Color get accent => switch (this) {
    rocketLaunch => LS.blue,
    memoryLane => LS.aqua,
    quickMath => LS.teal,
    guessColor => LS.violet,
    angleSense => LS.gold,
    lineSplit => LS.pink,
  };

  IconData get icon => switch (this) {
    rocketLaunch => Icons.rocket_launch_outlined,
    memoryLane => Icons.grid_view_rounded,
    quickMath => Icons.calculate_outlined,
    guessColor => Icons.palette_outlined,
    angleSense => Icons.architecture,
    lineSplit => Icons.straighten,
  };

  String get rules => switch (this) {
    rocketLaunch =>
      'Touch and drag anywhere to steer through the asteroid storm. It keeps getting faster — one hit ends the run.',
    memoryLane =>
      'Tiles light up one at a time. Tap them back in the same order. Every level adds a tile — one wrong tap ends the run.',
    quickMath =>
      'Solve problem after problem as they get harder. One wrong answer ends the run, and your time is saved.',
    guessColor =>
      'COLOR: tap the color it is painted in. TEXT: tap the color it spells out. Buttons shuffle, labels lie and the clock tightens — one wrong tap ends the run.',
    angleSense =>
      'READ: set the tape to the angle you see, then Lock. DRAW: drag the arm to the angle shown. Close enough keeps you going; within 3° is Sharp. You have 2 shields: each miss breaks one.',
    lineSplit =>
      'Touch the line where the number falls: ½, then ⅓, ⅜, 0.43… Slide to adjust and let go to answer. Close enough keeps you going. You have 2 shields: each miss breaks one.',
  };

  /// One short pointer for the next run, shown on the Game Over card.
  String get tip => switch (this) {
    rocketLaunch => 'Small moves: drag a little and keep to open space.',
    memoryLane => 'Say the order to yourself as the tiles light up.',
    quickMath => 'Accuracy beats speed: one wrong answer ends the run.',
    guessColor => 'Check COLOR or TEXT at the top before every tap.',
    angleSense => 'Picture 90° first, then judge the angle from it.',
    lineSplit => 'Find the middle first, then split from there.',
  };

  /// How a ramp game escalates; null for games with difficulty levels.
  String? get rampNote => switch (this) {
    rocketLaunch => 'Gets faster as you go',
    guessColor => 'Gets trickier as you go',
    lineSplit => 'Gets finer as you go',
    memoryLane || quickMath || angleSense => null,
  };

  /// What each difficulty changes. Empty for ramp games.
  String detail(Difficulty difficulty) => switch ((this, difficulty)) {
    (memoryLane, Difficulty.easy) => '3×3 grid',
    (memoryLane, Difficulty.medium) => '4×4 grid',
    (memoryLane, Difficulty.hard) => '5×5 grid',
    (quickMath, Difficulty.easy) => '+ and −',
    (quickMath, Difficulty.medium) => '+ − ×',
    (quickMath, Difficulty.hard) => '+ − × ÷',
    (angleSense, Difficulty.easy) => 'One arm stays put · no timer',
    (angleSense, Difficulty.medium) => 'Clocks, pies, compass · timer',
    (angleSense, Difficulty.hard) => 'Any angle, any way · fast',
    _ => '',
  };
}
