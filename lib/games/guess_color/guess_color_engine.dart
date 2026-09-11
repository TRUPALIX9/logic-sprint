import 'dart:async';
import 'dart:math';

import 'package:flutter/painting.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../round_engine.dart';

enum InkColor {
  red('Red', LS.coral),
  blue('Blue', LS.blue),
  green('Green', LS.teal),
  yellow('Yellow', LS.gold),
  purple('Purple', LS.violet),
  white('White', LS.text);

  const InkColor(this.label, this.color);
  final String label;
  final Color color;
}

/// How tricky the current word is. The round ramps by word number:
/// words 1–8 [warmUp], 9–18 [full], 19+ [shuffled].
enum GuessPhase {
  /// 4 colors; about 1 in 4 words match their ink.
  warmUp,

  /// 6 colors; the word never matches its ink.
  full,

  /// 6 colors, never matching, and the buttons reshuffle every word.
  shuffled;

  static GuessPhase of(int number) => number <= 8
      ? warmUp
      : number <= 18
      ? full
      : shuffled;

  List<InkColor> get palette =>
      this == warmUp ? InkColor.values.sublist(0, 4) : InkColor.values;
}

class StroopWord {
  const StroopWord(this.word, this.ink, this.buttons);

  /// The color the word names.
  final InkColor word;

  /// The color the word is painted in — the right answer.
  final InkColor ink;

  /// Answer buttons in display order.
  final List<InkColor> buttons;

  bool get congruent => word == ink;
}

/// Guess Color (Stroop): tap the ink color, not the word it spells. One
/// mode that gets trickier as the round goes on (see [GuessPhase]);
/// [difficulty] is ignored.
class GuessColorEngine extends RoundEngine {
  GuessColorEngine({
    required super.difficulty,
    super.previousBest,
    super.feedback,
    super.random,
  }) : super(game: GameId.guessColor) {
    item = generate(number, random);
  }

  static const _feedbackPause = Duration(milliseconds: 250);

  late StroopWord item;
  int number = 1;

  /// The color just tapped; non-null while its feedback shows.
  InkColor? picked;
  Timer? _next;

  bool get locked => picked != null || isFinished;
  GuessPhase get phase => GuessPhase.of(number);

  /// The word shown as word [number] (1-based).
  static StroopWord generate(int number, Random random) {
    final phase = GuessPhase.of(number);
    final palette = phase.palette;
    final word = palette[random.nextInt(palette.length)];
    final congruent = phase == GuessPhase.warmUp && random.nextInt(4) == 0;
    final others = [...palette]..remove(word);
    final ink = congruent ? word : others[random.nextInt(others.length)];
    final buttons = phase == GuessPhase.shuffled
        ? ([...palette]..shuffle(random))
        : palette;
    return StroopWord(word, ink, buttons);
  }

  void pick(InkColor color) {
    if (locked) {
      return;
    }
    picked = color;
    if (color == item.ink) {
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
      item = generate(number, random);
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
