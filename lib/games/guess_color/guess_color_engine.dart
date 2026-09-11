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

  /// Button fill and border when tinted in this color. Every [color] keeps
  /// ≥ 4.5:1 contrast on every [fill] (checked in tests).
  Color get fill => color.withValues(alpha: 0.08);
  Color get border => color.withValues(alpha: 0.4);
}

/// How tricky the current word is. The run ramps by word number, and each
/// phase keeps the rules of the ones before it:
/// - 1–8 [warmUp]: 4 colors, fixed order, about 1 in 4 words match their ink.
/// - 9–18 [full]: 6 colors; the word never matches its ink.
/// - 19–30 [shuffled]: button order reshuffles every word.
/// - 31–45 [mislabeled]: each name is drawn in a different color, no swatch.
/// - 46+ [tinted]: each button is also tinted in a third, unrelated color.
enum GuessPhase {
  warmUp,
  full,
  shuffled,
  mislabeled,
  tinted;

  static GuessPhase of(int number) => switch (number) {
    <= 8 => warmUp,
    <= 18 => full,
    <= 30 => shuffled,
    <= 45 => mislabeled,
    _ => tinted,
  };

  List<InkColor> get palette =>
      this == warmUp ? InkColor.values.sublist(0, 4) : InkColor.values;

  bool get allowsCongruent => this == warmUp;
  bool get shuffles => index >= shuffled.index;
  bool get mislabels => index >= mislabeled.index;
  bool get tints => this == tinted;
}

/// One answer button. It is identified by [name] (its text); [label] is the
/// color that text is drawn in and [tint] colors its fill and border.
class ColorChoice {
  const ColorChoice(this.name, {InkColor? label, InkColor? tint})
    : label = label ?? name,
      tint = tint ?? name;

  final InkColor name;
  final InkColor label;
  final InkColor tint;

  /// The honest swatch only shows while names are drawn in their own color.
  bool get swatch => label == name;
}

class StroopWord {
  const StroopWord(this.word, this.ink, this.buttons);

  /// The color the word names.
  final InkColor word;

  /// The color the word is painted in — the right answer.
  final InkColor ink;

  /// Answer buttons in display order.
  final List<ColorChoice> buttons;

  bool get congruent => word == ink;
}

/// Guess Color (Stroop): tap the button named after the ink color, not the
/// word it spells. Endless; gets trickier by word number (see [GuessPhase]);
/// one wrong pick ends the run. [difficulty] is ignored.
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

  bool get locked => picked != null || !isPlaying;
  GuessPhase get phase => GuessPhase.of(number);

  /// The word shown as word [number] (1-based).
  static StroopWord generate(int number, Random random) {
    final phase = GuessPhase.of(number);
    final palette = phase.palette;
    final word = palette[random.nextInt(palette.length)];
    final congruent = phase.allowsCongruent && random.nextInt(4) == 0;
    final others = [...palette]..remove(word);
    final ink = congruent ? word : others[random.nextInt(others.length)];

    final names = phase.shuffles ? ([...palette]..shuffle(random)) : palette;
    if (!phase.mislabels) {
      return StroopWord(word, ink, [
        for (final name in names) ColorChoice(name),
      ]);
    }
    final labels = _derange(names, random);
    final buttons = <ColorChoice>[];
    for (var i = 0; i < names.length; i++) {
      final name = names[i], label = labels[i];
      InkColor? tint;
      if (phase.tints) {
        final free = [
          for (final c in palette)
            if (c != name && c != label) c,
        ];
        tint = free[random.nextInt(free.length)];
      }
      buttons.add(ColorChoice(name, label: label, tint: tint));
    }
    return StroopWord(word, ink, buttons);
  }

  /// A shuffle of [names] where no color stays in its own slot.
  static List<InkColor> _derange(List<InkColor> names, Random random) {
    while (true) {
      final colors = [...names]..shuffle(random);
      var clash = false;
      for (var i = 0; i < names.length; i++) {
        clash = clash || colors[i] == names[i];
      }
      if (!clash) {
        return colors;
      }
    }
  }

  void _nextWord() {
    picked = null;
    number++;
    item = generate(number, random);
    notify();
  }

  void pick(InkColor color) {
    if (locked) {
      return;
    }
    picked = color;
    if (color == item.ink) {
      scoreCorrect();
      _next = Timer(_feedbackPause, () {
        if (isPlaying) {
          _nextWord();
        }
      });
    } else {
      // Keeps [picked] so the wrong pick and the right answer stay visible.
      fail();
    }
  }

  @override
  void onDown() => _next?.cancel();

  @override
  void onRevive() => _nextWord();

  @override
  void onFinish() => _next?.cancel();

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }
}
