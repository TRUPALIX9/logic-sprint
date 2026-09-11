import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/painting.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../round_engine.dart';

enum InkColor {
  red('Red', LS.coral),
  blue('Blue', LS.blue),
  green('Green', LS.teal),
  yellow('Yellow', LS.gold);

  const InkColor(this.label, this.color);
  final String label;
  final Color color;
}

/// Which color the right button's fill must match.
enum GuessRule {
  /// COLOR: tap the color the item is painted in.
  color,

  /// TEXT: tap the color the word says.
  text,
}

enum ItemKind { word, neutralWord, shape }

enum GuessShape { circle, square, triangle, star }

/// The run ramps by word number; each stage keeps the rules before it:
/// - 1–5 [classic]: rule COLOR, fixed order, labels match fills, about 1 in 4
///   words congruent (the only stage with congruent words).
/// - 6–12 [shuffled]: button order reshuffles every word.
/// - 13–20 [timed]: per-word countdown, 3.0 s at word 13, −0.05 s per word,
///   floor 1.0 s. Running out is a mistake.
/// - 21–30 [ruleSwap]: rule swaps between COLOR and TEXT (about 35% TEXT); a
///   new rule holds for at least [minRuleRun] words.
/// - 31–40 [mislabeled]: every label names a different color than its fill.
/// - 41+ [neutral]: about 30% of COLOR turns show a neutral word or a shape,
///   and the item gets rotation/pulse/shake distractions.
enum GuessStage {
  classic,
  shuffled,
  timed,
  ruleSwap,
  mislabeled,
  neutral;

  static GuessStage of(int number) => switch (number) {
    <= 5 => classic,
    <= 12 => shuffled,
    <= 20 => timed,
    <= 30 => ruleSwap,
    <= 40 => mislabeled,
    _ => neutral,
  };

  bool _from(GuessStage stage) => index >= stage.index;

  bool get allowsCongruent => this == classic;
  bool get shuffles => _from(shuffled);
  bool get hasCountdown => _from(timed);
  bool get swapsRules => _from(ruleSwap);
  bool get mislabels => _from(mislabeled);
  bool get hasNeutrals => _from(neutral);
  bool get distracts => _from(neutral);
}

/// One answer button, identified by its [fill]. [label] is only text; from
/// word 31 it names a different color (a trap).
class ColorButton {
  const ColorButton(this.fill, [InkColor? label]) : label = label ?? fill;

  final InkColor fill;
  final InkColor label;
}

/// The item on the card and the buttons to answer it with.
class GuessItem {
  const GuessItem({
    required this.kind,
    required this.ink,
    required this.rule,
    required this.buttons,
    this.word,
    this.neutral,
    this.shape,
    this.ruleChanged = false,
    this.rotationDegrees = 0,
    this.pulse = false,
    this.shake = false,
  });

  final ItemKind kind;

  /// The color painting the word, neutral word or shape.
  final InkColor ink;
  final GuessRule rule;

  /// True on the first word of a new rule (for a flip animation).
  final bool ruleChanged;

  final List<ColorButton> buttons;

  /// The color the word names; null for neutral items.
  final InkColor? word;

  /// The neutral word shown when [kind] is [ItemKind.neutralWord].
  final String? neutral;

  /// The shape shown when [kind] is [ItemKind.shape].
  final GuessShape? shape;

  /// Distractions for the UI to render; zero/false before word 41.
  final double rotationDegrees;
  final bool pulse;
  final bool shake;

  /// The fill of the right button.
  InkColor get target => rule == GuessRule.text ? word! : ink;

  bool get congruent => word == ink;

  /// The text on the card; null for shapes.
  String? get text => switch (kind) {
    ItemKind.word => word!.label,
    ItemKind.neutralWord => neutral,
    ItemKind.shape => null,
  };
}

/// Guess Color (Stroop): tap the button whose fill matches the target color.
/// Endless; gets trickier by word number (see [GuessStage]); a wrong pick or
/// a timeout ends the run. [difficulty] is ignored.
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
  static const minRuleRun = 2;
  static const textRuleChance = 0.35;
  static const neutralChance = 0.3;
  static const neutralWords = ['Table', 'Chair', 'Cloud', 'River', 'Stone'];

  late GuessItem item;
  int number = 1;

  /// The fill just tapped; non-null while its feedback shows.
  InkColor? picked;

  /// True when the run went down because the countdown ran out.
  bool timedOut = false;

  /// When the current word's countdown began (package:clock time).
  DateTime? wordStartedAt;

  Timer? _next;
  Timer? _countdown;
  int _ruleRun = 1;

  bool get locked => picked != null || !isPlaying;
  GuessStage get stage => GuessStage.of(number);
  GuessRule get rule => item.rule;
  bool get ruleChanged => item.ruleChanged;

  /// The current word's countdown; null before word 13.
  Duration? get timeLimit => timeLimitFor(number);

  /// The countdown on word 13; each later word gets 50 ms less, to 1 s.
  static const maxTimeLimit = Duration(seconds: 3);

  static Duration? timeLimitFor(int number) {
    if (!GuessStage.of(number).hasCountdown) {
      return null;
    }
    final ms = maxTimeLimit.inMilliseconds - 50 * (number - 13);
    return Duration(milliseconds: max(1000, ms));
  }

  /// The item for word [number]. [previousRule] and [ruleRun] (words shown
  /// under it so far) keep each new rule for at least [minRuleRun] words.
  static GuessItem generate(
    int number,
    Random random, {
    GuessRule previousRule = GuessRule.color,
    int ruleRun = minRuleRun,
  }) {
    final stage = GuessStage.of(number);
    const colors = InkColor.values;
    T any<T>(List<T> list) => list[random.nextInt(list.length)];

    var rule = GuessRule.color;
    if (stage.swapsRules) {
      final wanted = random.nextDouble() < textRuleChance
          ? GuessRule.text
          : GuessRule.color;
      rule = ruleRun < minRuleRun ? previousRule : wanted;
    }

    final ink = any(colors);
    var kind = ItemKind.word;
    if (stage.hasNeutrals &&
        rule == GuessRule.color &&
        random.nextDouble() < neutralChance) {
      kind = random.nextBool() ? ItemKind.neutralWord : ItemKind.shape;
    }
    InkColor? word;
    if (kind == ItemKind.word) {
      final congruent = stage.allowsCongruent && random.nextInt(4) == 0;
      word = congruent ? ink : any([...colors]..remove(ink));
    }

    final fills = stage.shuffles ? ([...colors]..shuffle(random)) : colors;
    final labels = stage.mislabels ? _derange(fills, random) : fills;

    return GuessItem(
      kind: kind,
      ink: ink,
      rule: rule,
      ruleChanged: rule != previousRule,
      buttons: [
        for (var i = 0; i < fills.length; i++) ColorButton(fills[i], labels[i]),
      ],
      word: word,
      neutral: kind == ItemKind.neutralWord ? any(neutralWords) : null,
      shape: kind == ItemKind.shape ? any(GuessShape.values) : null,
      rotationDegrees: stage.distracts ? random.nextDouble() * 20 - 10 : 0,
      pulse: stage.distracts && random.nextInt(3) == 0,
      shake: stage.distracts && random.nextInt(5) == 0,
    );
  }

  /// A shuffle of [colors] where no color stays in its own slot.
  static List<InkColor> _derange(List<InkColor> colors, Random random) {
    while (true) {
      final shuffled = [...colors]..shuffle(random);
      var clash = false;
      for (var i = 0; i < colors.length; i++) {
        clash = clash || shuffled[i] == colors[i];
      }
      if (!clash) {
        return shuffled;
      }
    }
  }

  void _setItem(GuessItem next) {
    _ruleRun = next.ruleChanged ? 1 : _ruleRun + 1;
    item = next;
  }

  /// Clears feedback and (re)starts the current word's countdown.
  void _showWord() {
    picked = null;
    timedOut = false;
    wordStartedAt = clock.now();
    _countdown?.cancel();
    final limit = timeLimit;
    _countdown = limit == null ? null : Timer(limit, _timeUp);
    notify();
  }

  void _timeUp() {
    if (!isPlaying || picked != null) {
      return;
    }
    timedOut = true;
    fail();
  }

  void _nextWord() {
    number++;
    _setItem(
      generate(number, random, previousRule: item.rule, ruleRun: _ruleRun),
    );
    _showWord();
  }

  void pick(InkColor fill) {
    if (locked) {
      return;
    }
    picked = fill;
    _countdown?.cancel();
    if (fill == item.target) {
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

  void _cancelTimers() {
    _next?.cancel();
    _countdown?.cancel();
  }

  @override
  void onStart() => _showWord();

  @override
  void onDown() => _cancelTimers();

  /// A fresh item at the same word number (same stage and rule).
  @override
  void onRevive() {
    _setItem(generate(number, random, previousRule: item.rule, ruleRun: 0));
    _showWord();
  }

  @override
  void onFinish() => _cancelTimers();

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
