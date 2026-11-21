import 'dart:math';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../models/game.dart';
import '../round_engine.dart';

/// The run ramps by question number; each stage adds one new kind of line or
/// target:
/// - 1–6 [halves] ("Flat"): a long flat line; Q1 is ½ and Q2 is ⅓ (the
///   only times those two are asked), then ⅔, ¼, ¾.
/// - 7–12 [upright]: a vertical line (0 at the bottom); ⅔, ¼, ¾, ⅕, ⅘.
/// - 13–20 [crossed]: a diagonal line crossed by a faint decoy line;
///   ⅔, quarters and eighths.
/// - 21–30 [finer]: any direction and shorter lines; eighths and fifths.
/// - 31–40 [decimals]: decimals and percents that avoid simple fractions;
///   a 5 s timer.
/// - 41–50 [tricks]: counted from the 1 end, or fake tick marks; 4 s.
/// - 51+ [everything]: any of the above; 3.5 s.
///
/// Lines by question: Q1–16 only 0–1; from Q17 about 1 in 3 lines are
/// longer number lines (0 · 1 · 2, see [SplitTarget.units]) with mixed
/// numbers and decimals; 0 · 1 · 2 · 3 lines from Q31; improper fractions
/// from Q36; the middle whole numbers hidden from Q43, and improper
/// fractions on hidden lines from Q46. Longer-line fractions use any
/// denominator from 2 to 8 (11/5, 7/6, 9/7…), picked evenly.
enum SplitStage {
  halves('Flat', 5),
  upright('Upright', 5),
  crossed('Crossed', 5.5),
  finer('Eighths · fifths', 5.5),
  decimals('Decimals', 6, Duration(seconds: 5)),
  tricks('Tricks', 6, Duration(seconds: 4)),
  everything('Everything', 5.5, Duration(milliseconds: 3500));

  const SplitStage(this.title, this.window, [this.timeLimit]);

  final String title;

  /// The widest hit, in percent of the line's length.
  final double window;

  /// Time to answer; null when untimed.
  final Duration? timeLimit;

  static SplitStage of(int number) => switch (number) {
    <= 6 => halves,
    <= 12 => upright,
    <= 20 => crossed,
    <= 30 => finer,
    <= 40 => decimals,
    <= 50 => tricks,
    _ => everything,
  };
}

/// How a target is written above the card.
enum TargetKind { fraction, decimal, percent }

/// What to aim for. [position] is always measured from the 0 end, even when
/// the player is told to count from the 1 end ([fromOne]), and is a share of
/// the whole line however many [units] it spans.
@immutable
class SplitTarget {
  const SplitTarget.fraction(
    int this.numerator,
    int this.denominator, {
    this.units = 1,
    this.unitTicks = true,
  }) : kind = TargetKind.fraction,
       whole = 0,
       shown = numerator / denominator,
       fromOne = false,
       ticks = false;

  /// A mixed number on a longer line: [whole] and [numerator]/[denominator]
  /// (1½ is `mixed(1, 1, 2)`).
  const SplitTarget.mixed(
    this.whole,
    int this.numerator,
    int this.denominator, {
    this.units = 2,
    this.unitTicks = true,
  }) : kind = TargetKind.fraction,
       shown = whole + numerator / denominator,
       fromOne = false,
       ticks = false;

  const SplitTarget.decimal(
    this.shown, {
    this.fromOne = false,
    this.ticks = false,
    this.units = 1,
    this.unitTicks = true,
  }) : kind = TargetKind.decimal,
       whole = 0,
       numerator = null,
       denominator = null;

  const SplitTarget.percent(this.shown)
    : kind = TargetKind.percent,
      whole = 0,
      numerator = null,
      denominator = null,
      fromOne = false,
      ticks = false,
      units = 1,
      unitTicks = true;

  final TargetKind kind;

  /// The value written on screen, counted from the end the player is told,
  /// in units of the line (0..[units]).
  final double shown;

  /// The whole part of a mixed number; 0 otherwise.
  final int whole;
  final int? numerator;
  final int? denominator;

  /// Count from the 1 end ("0.30 from the 1 end"). Only on a 0–1 line.
  final bool fromOne;

  /// The line carries fake tick marks ("ignore the ticks"). Only on a 0–1
  /// line.
  final bool ticks;

  /// How many units the line spans: 1 (0–1), 2 (0 · 1 · 2) or 3 (0–3).
  final int units;

  /// The inner whole numbers (the 1 on a 0 · 1 · 2 line) are drawn and
  /// labelled. False: only the two ends are shown.
  final bool unitTicks;

  bool get isMultiUnit => units > 1;

  /// A fraction above 1 written as one, like 11/8.
  bool get isImproper =>
      kind == TargetKind.fraction && whole == 0 && numerator! > denominator!;

  /// Where the answer lies, as a share of the line from the 0 end (0..1).
  double get position => fromOne ? 1 - shown : shown / units;

  /// "0.43", "1.6" or "37%"; null for a fraction (drawn stacked).
  String? get text => switch (kind) {
    TargetKind.fraction => null,
    TargetKind.decimal => isMultiUnit ? _trim(shown) : shown.toStringAsFixed(2),
    TargetKind.percent => '${(shown * 100).round()}%',
  };

  /// "1 1/2" or "11/8" (plain text for screen readers and logs).
  String get fractionText =>
      whole > 0 ? '$whole $numerator/$denominator' : '$numerator/$denominator';

  String get subtitle => ticks
      ? 'ignore the ticks'
      : fromOne
      ? 'from the 1 end'
      : isMultiUnit
      ? 'on 0 to $units'
      : 'from the 0 end';

  /// For screen readers: "3/8 from the 0 end", "1 1/2 on a line from 0 to 2".
  String get spoken =>
      '${text ?? fractionText} ${isMultiUnit
          ? 'on a line from 0 to $units'
          : fromOne
          ? 'from the 1 end'
          : 'from the 0 end'}';

  /// Same aim point, the same end to count from and the same line.
  bool sameAs(SplitTarget other) =>
      (position * 1000).round() == (other.position * 1000).round() &&
      fromOne == other.fromOne &&
      units == other.units;

  /// 1.60 → "1.6", 2.25 → "2.25".
  static String _trim(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
  }

  @override
  String toString() => '${text ?? fractionText} $subtitle';
}

/// A straight line on the card. Sizes are in units of the frame's shortest
/// side, centred on the frame (plus [shift]). [degrees] turns it
/// counter-clockwise from flat; the 0 end is at the left (the bottom when
/// upright).
@immutable
class SplitLine {
  const SplitLine({
    required this.degrees,
    required this.length,
    this.shift = Offset.zero,
  });

  final double degrees;
  final double length;
  final Offset shift;

  bool get isFlat => degrees == 0;
  bool get isUpright => degrees.abs() == 90;

  /// The unit vector from the 0 end towards the 1 end (screen y is down).
  Offset get direction {
    final radians = degrees * pi / 180;
    return Offset(cos(radians), -sin(radians));
  }

  Offset _center(Rect frame) => frame.center + shift * frame.shortestSide;

  Offset _half(Rect frame) => direction * (length * frame.shortestSide / 2);

  Offset start(Rect frame) => _center(frame) - _half(frame);
  Offset end(Rect frame) => _center(frame) + _half(frame);

  /// The point [u] of the way from the 0 end to the 1 end.
  Offset at(Rect frame, double u) => Offset.lerp(start(frame), end(frame), u)!;

  /// [point] projected onto the line, as a share of its length from the 0
  /// end, clamped to 0..1.
  double project(Rect frame, Offset point) {
    final a = start(frame);
    final ab = end(frame) - a;
    final ap = point - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared == 0) {
      return 0;
    }
    return ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  }
}

/// One question: the target, the line to split, and any decoys.
@immutable
class SplitQuestion {
  const SplitQuestion({
    required this.target,
    required this.line,
    this.decoy,
    this.ticks = const [],
  });

  final SplitTarget target;
  final SplitLine line;

  /// A faint second line crossing [line] (it doesn't count).
  final SplitLine? decoy;

  /// Fake tick marks on [line], as shares from the 0 end.
  final List<double> ticks;
}

enum SplitVerdict {
  bullseye('Bullseye'),
  sharp('Sharp'),
  hit('Hit'),
  miss('Miss'),
  time('Time');

  const SplitVerdict(this.label);
  final String label;

  bool get isHit => index <= hit.index;
}

/// How the answer is revealed on the card:
/// - [perfect]: a Bullseye. The line turns gold, a pulse runs to both ends.
/// - [close]: a Sharp, or a miss just past the window
///   ([LineSplitEngine.nearMissMargin]). A slow-motion zoom shows the gap.
/// - [normal]: an ordinary hit, a far miss or a timeout.
enum RevealTier { perfect, close, normal }

/// How an answer went. Errors are in percent of the line's length.
@immutable
class SplitOutcome {
  const SplitOutcome({
    required this.answer,
    required this.error,
    required this.signedError,
    required this.verdict,
    this.points = 0,
    this.tier = RevealTier.normal,
  });

  /// Where the player let go, from the 0 end; null on a timeout.
  final double? answer;
  final double error;

  /// Positive past the target, counted from the end the player was told.
  final double signedError;
  final SplitVerdict verdict;
  final int points;
  final RevealTier tier;

  /// A miss shown with the slow-motion zoom.
  bool get nearMiss => tier == RevealTier.close && !verdict.isHit;

  /// "+1.6%" or "−1.6%".
  String get _signed {
    final rounded = signedError.abs().toStringAsFixed(1);
    final sign = signedError < 0 && rounded != '0.0' ? '−' : '+';
    return '$sign$rounded%';
  }

  /// "SHARP −1.6%", or "TIME".
  String get label => verdict == SplitVerdict.time
      ? 'TIME'
      : '${verdict.label.toUpperCase()} $_signed';

  /// The chip on the card: "PERFECT +0.4%" for a Bullseye, "SO CLOSE +7.0%"
  /// for a near miss, otherwise [label].
  String get headline => switch (tier) {
    RevealTier.perfect => 'PERFECT $_signed',
    RevealTier.close when nearMiss => 'SO CLOSE $_signed',
    _ => label,
  };
}

/// Line Split: press on the card, slide along the line and let go where the
/// target lies. Endless with 2 shields ([strikesLeft]): a miss or a timeout
/// breaks one, losing the second goes down (after a close reveal has played).
/// A revive gives back one shield. Ramps by question number (see [SplitStage]).
/// [difficulty] is ignored.
class LineSplitEngine extends RoundEngine {
  LineSplitEngine({
    required super.difficulty,
    super.previousBest,
    super.feedback,
    super.random,
  }) : super(game: GameId.lineSplit) {
    question = generate(number, random);
  }

  static const maxStrikes = 2;
  static const basePoints = 10;
  static const sharpBonus = 5;
  static const bullseyeBonus = 10;
  static const sharpWithin = 2.0;
  static const bullseyeWithin = 1.0;
  static const hitPause = Duration(milliseconds: 900);
  static const missPause = Duration(milliseconds: 1200);

  /// A miss within the window plus this (percent of the line) still gets
  /// the slow-motion reveal.
  static const nearMissMargin = 2.5;

  /// The golden-line reveal of a Bullseye.
  static const perfectPause = Duration(milliseconds: 900);

  /// The slow-motion slide in the zoom, then a hold on the final state.
  static const closeSlide = Duration(milliseconds: 1600);
  static const closeHold = Duration(milliseconds: 400);
  static const closePause = Duration(milliseconds: 2000);

  /// Longer number lines (0 · 1 · 2) appear from this question, about 1 in
  /// [multiOneIn].
  static const multiFrom = 17;
  static const multiOneIn = 3;

  /// Improper fractions (11/8) on longer lines from here.
  static const improperFrom = 36;

  /// 0 · 1 · 2 · 3 lines (ticks shown) join from here, about 1 in
  /// [threeOneIn] longer lines; thirds are the hardest split to see.
  static const threeFrom = 31;
  static const threeOneIn = 3;

  /// The middle whole numbers may be hidden from here.
  static const hiddenFrom = 43;

  /// Improper fractions on hidden-tick lines from here.
  static const improperHiddenFrom = 46;

  /// Denominators of fraction targets on longer lines.
  static const spanDenominators = [2, 3, 4, 5, 6, 7, 8];

  /// A longer-line target keeps at least this far (in units) from every
  /// whole number.
  static const wholeGap = 0.1;

  /// A target this far from the far end is too easy (judge ¼ from an end).
  static const _unitFractions = [
    1 / 2,
    1 / 3,
    1 / 4,
    1 / 5,
    1 / 6,
    1 / 7,
    1 / 8,
  ];

  /// The longest timer (the bar's full width).
  static const maxTimeLimit = Duration(seconds: 5);

  /// Decimals stay at least this far from every simple fraction.
  static const fractionGap = 0.025;

  static const simpleFractions = [
    (1, 2),
    (1, 3),
    (2, 3),
    (1, 4),
    (3, 4),
    (1, 5),
    (2, 5),
    (3, 5),
    (4, 5),
    (1, 8),
    (3, 8),
    (5, 8),
    (7, 8),
  ];

  static const _flat = [(2, 3), (1, 4), (3, 4)];
  static const _upright = [(2, 3), (1, 4), (3, 4), (1, 5), (4, 5)];
  static const _crossed = [
    (2, 3),
    (1, 4),
    (3, 4),
    (1, 8),
    (3, 8),
    (5, 8),
    (7, 8),
  ];
  static const _finer = [
    (1, 8),
    (3, 8),
    (5, 8),
    (7, 8),
    (1, 5),
    (2, 5),
    (3, 5),
    (4, 5),
  ];
  static const _anyAngle = <double>[0, 90, 15, -15, 30, -30, 45, -45, 60, -60];

  late SplitQuestion question;
  int number = 1;
  int strikesLeft = maxStrikes;

  /// The live marker while the player presses, from the 0 end.
  final ValueNotifier<double?> aim = ValueNotifier(null);

  /// Set once the current question is answered (or timed out).
  SplitOutcome? outcome;

  /// When the current question was shown (package:clock time).
  DateTime? questionStartedAt;

  PausableTimer? _next;
  PausableTimer? _countdown;

  SplitStage get stage => SplitStage.of(number);
  SplitTarget get target => question.target;
  double get window => stage.window;
  Duration? get timeLimit => stage.timeLimit;
  bool get timedOut => outcome?.verdict == SplitVerdict.time;

  bool get locked => outcome != null || !isPlaying;

  /// What's left of the countdown (frozen while paused); null when none is
  /// running.
  Duration? get timeLeft {
    final countdown = _countdown;
    return countdown != null && countdown.isActive ? countdown.remaining : null;
  }

  /// A decimal 0.06–0.94 (2 places) at least [fractionGap] from every
  /// [simpleFractions] value.
  static double decimal(Random random) {
    while (true) {
      final value = (6 + random.nextInt(89)) / 100;
      final clear = simpleFractions.every(
        (f) => (value - f.$1 / f.$2).abs() >= fractionGap - 1e-9,
      );
      if (clear) {
        return value;
      }
    }
  }

  /// Whether [value] is a fair target on a 0..[units] line: inside it, at
  /// least [wholeGap] from every whole number (never on an end or a tick),
  /// and not a unit fraction (½ ⅓ ¼ ⅕ ⅛) back from the far end.
  static bool fairOnSpan(double value, int units) {
    if (value <= 0 || value >= units) {
      return false;
    }
    if ((value - value.roundToDouble()).abs() < wholeGap - 1e-9) {
      return false;
    }
    final fromFar = units - value;
    return _unitFractions.every((f) => (fromFar - f).abs() > 1e-9);
  }

  /// Every fair fraction n/d (lowest terms) on a 0..[units] line, d from
  /// [spanDenominators].
  static List<(int, int)> spanFractions(int units) => [
    for (final d in spanDenominators)
      for (var n = 1; n < units * d; n++)
        if (n.gcd(d) == 1 && fairOnSpan(n / d, units)) (n, d),
  ];

  /// A fair decimal in steps of 0.05 on a 0..[units] line.
  static double spanDecimal(int units, Random random) {
    while (true) {
      final value = (1 + random.nextInt(units * 20 - 1)) / 20;
      if (fairOnSpan(value, units)) {
        return value;
      }
    }
  }

  /// The question for [number]; never the same target as [previous].
  static SplitQuestion generate(
    int number,
    Random random, {
    SplitTarget? previous,
  }) {
    final stage = SplitStage.of(number);
    final multi = number >= multiFrom && random.nextInt(multiOneIn) == 0;
    SplitTarget pick() =>
        multi ? _spanTarget(number, random) : _target(stage, random, number);
    var target = pick();
    for (
      var i = 0;
      i < 50 && previous != null && target.sameAs(previous);
      i++
    ) {
      target = pick();
    }
    double between(double lo, double hi) =>
        lo + random.nextDouble() * (hi - lo);
    T any<T>(List<T> list) => list[random.nextInt(list.length)];

    final SplitLine line;
    SplitLine? decoy;
    switch (stage) {
      case SplitStage.halves:
        line = SplitLine(degrees: 0, length: between(0.8, 0.92));
      case SplitStage.upright:
        line = SplitLine(degrees: 90, length: between(0.8, 0.92));
      case SplitStage.crossed:
        line = SplitLine(
          degrees: any(<double>[30, -30, 60, -60]),
          length: between(0.8, 0.92),
        );
        decoy = _decoyFor(line, random);
      case _:
        // Longer number lines keep a long line so each unit has room.
        line = SplitLine(
          degrees: any(_anyAngle),
          length: between(multi ? 0.8 : 0.6, 0.92),
        );
        if (stage == SplitStage.everything &&
            line.degrees != 0 &&
            !line.isUpright &&
            random.nextInt(4) == 0) {
          decoy = _decoyFor(line, random);
        }
    }
    return SplitQuestion(
      target: target,
      line: line,
      decoy: decoy,
      ticks: target.ticks ? _ticks(target.position, random) : const [],
    );
  }

  /// The two easy openers, each asked once: Q1 is ½, Q2 is ⅓. They never
  /// come back, so the run moves on instead of repeating them.
  static const easyOpeners = [(1, 2), (1, 3)];

  static SplitTarget _target(SplitStage stage, Random random, int number) {
    T any<T>(List<T> list) => list[random.nextInt(list.length)];
    SplitTarget fraction(List<(int, int)> set) {
      final (n, d) = any(set);
      return SplitTarget.fraction(n, d);
    }

    SplitTarget trick() => random.nextBool()
        ? SplitTarget.decimal(decimal(random), fromOne: true)
        : SplitTarget.decimal(decimal(random), ticks: true);

    return switch (stage) {
      SplitStage.halves => switch (number) {
        1 => const SplitTarget.fraction(1, 2),
        2 => const SplitTarget.fraction(1, 3),
        _ => fraction(_flat),
      },
      SplitStage.upright => fraction(_upright),
      SplitStage.crossed => fraction(_crossed),
      SplitStage.finer => fraction(_finer),
      SplitStage.decimals =>
        random.nextBool()
            ? SplitTarget.decimal(decimal(random))
            : SplitTarget.percent(decimal(random)),
      SplitStage.tricks => trick(),
      SplitStage.everything => switch (random.nextInt(5)) {
        0 => fraction([..._crossed, ..._finer]),
        1 => SplitTarget.decimal(decimal(random)),
        2 => SplitTarget.percent(decimal(random)),
        _ => trick(),
      },
    };
  }

  /// A target on a longer number line (see [SplitStage]). Before
  /// [improperFrom]: mixed numbers and decimals; then about half the
  /// fractions are improper (only where the middle 1 shows until
  /// [improperHiddenFrom]). Fractions prefer values past an inner whole
  /// number (3 in 4).
  static SplitTarget _spanTarget(int number, Random random) {
    final hidden = number >= hiddenFrom && random.nextBool();
    final units = number >= threeFrom && random.nextInt(threeOneIn) == 0
        ? 3
        : 2;
    final unitTicks = !hidden;
    if (random.nextInt(3) == 0) {
      return SplitTarget.decimal(
        spanDecimal(units, random),
        units: units,
        unitTicks: unitTicks,
      );
    }
    final improperOk =
        number >= improperFrom && (unitTicks || number >= improperHiddenFrom);
    final improper = improperOk && random.nextBool();
    final all = spanFractions(units);
    final past = [
      for (final f in all)
        if (f.$1 > f.$2) f,
    ];
    final below = [
      for (final f in all)
        if (f.$1 < f.$2 && !easyOpeners.contains(f)) f,
    ];
    final pool = improper || random.nextInt(4) != 0 ? past : below;
    // Any fraction in the pool, evenly: with denominators 2–8 there are
    // enough that no one spot comes up often.
    final (n, d) = pool[random.nextInt(pool.length)];
    if (improper || n < d) {
      return SplitTarget.fraction(n, d, units: units, unitTicks: unitTicks);
    }
    return SplitTarget.mixed(
      n ~/ d,
      n % d,
      d,
      units: units,
      unitTicks: unitTicks,
    );
  }

  /// A faint line mirrored across the flat axis (an X), its centre slid along
  /// [line] so the crossing isn't the midpoint. Fits the frame.
  static SplitLine _decoyFor(SplitLine line, Random random) {
    final slide =
        (0.06 + random.nextDouble() * 0.06) * (random.nextBool() ? 1 : -1);
    final length = min(
      0.6 + random.nextDouble() * 0.2,
      2 * (0.5 - slide.abs()),
    );
    return SplitLine(
      degrees: -line.degrees,
      length: length,
      shift: line.direction * slide,
    );
  }

  /// 3–4 fake ticks near even spacings but off them, each at least 0.03 from
  /// [position].
  static List<double> _ticks(double position, Random random) {
    final count = 3 + random.nextInt(2);
    final ticks = <double>[];
    for (var k = 1; k <= count; k++) {
      final even = k / (count + 1);
      double tick;
      var tries = 0;
      do {
        final off = 0.03 + random.nextDouble() * 0.04;
        tick = (even + (random.nextBool() ? off : -off)).clamp(0.04, 0.96);
        tries++;
      } while ((tick - position).abs() < 0.03 && tries < 20);
      ticks.add(tick);
    }
    return ticks;
  }

  /// Clears the reveal and (re)starts the current question's countdown.
  void _show() {
    outcome = null;
    aim.value = null;
    questionStartedAt = clock.now();
    _countdown?.cancel();
    final limit = timeLimit;
    _countdown = limit == null ? null : PausableTimer(limit, _timeUp);
    notify();
  }

  void _nextQuestion() {
    number++;
    question = generate(number, random, previous: target);
    _show();
  }

  void _timeUp() {
    if (locked) {
      return;
    }
    _judge(null);
  }

  /// The finger touched down (a light tap haptic).
  void grab(double u) {
    if (locked) {
      return;
    }
    feedback?.tap();
    aim.value = u.clamp(0.0, 1.0);
  }

  /// Moves the live marker.
  void aimAt(double u) {
    if (locked) {
      return;
    }
    aim.value = u.clamp(0.0, 1.0);
  }

  /// Moves the marker by [delta] (the accessible slider; starts mid-line).
  void nudge(double delta) => aimAt((aim.value ?? 0.5) + delta);

  /// The press was cancelled: no answer.
  void dropAim() => aim.value = null;

  /// Answers at the live marker (the finger lifted).
  void release() {
    final u = aim.value;
    if (locked || u == null) {
      aim.value = null;
      return;
    }
    answer(u);
  }

  /// Answers at [u], a share of the line from the 0 end.
  void answer(double u) {
    if (locked) {
      return;
    }
    _judge(u.clamp(0.0, 1.0));
  }

  void _judge(double? u) {
    _countdown?.cancel();
    aim.value = null;
    final SplitOutcome result;
    if (u == null) {
      result = const SplitOutcome(
        answer: null,
        error: double.infinity,
        signedError: 0,
        verdict: SplitVerdict.time,
      );
    } else {
      final raw = (u - target.position) * 100;
      final error = raw.abs();
      const slack = 1e-9;
      final verdict = error > window + slack
          ? SplitVerdict.miss
          : error <= bullseyeWithin + slack
          ? SplitVerdict.bullseye
          : error <= sharpWithin + slack
          ? SplitVerdict.sharp
          : SplitVerdict.hit;
      final bonus = switch (verdict) {
        SplitVerdict.bullseye => bullseyeBonus,
        SplitVerdict.sharp => sharpBonus,
        _ => 0,
      };
      result = SplitOutcome(
        answer: u,
        error: error,
        signedError: target.fromOne ? -raw : raw,
        verdict: verdict,
        points: verdict.isHit ? basePoints + bonus : 0,
        tier: tierOf(verdict, error, window),
      );
    }
    outcome = result;
    final pause = pauseFor(result);

    if (result.verdict.isHit) {
      scoreCorrect(result.points);
      _next = PausableTimer(pause, _advance);
      return;
    }
    strikesLeft = max(0, strikesLeft - 1);
    breakStreak();
    if (strikesLeft == 0) {
      // Keeps [outcome] so the reveal stays visible while down.
      if (result.tier == RevealTier.close) {
        // Let the slow-motion reveal play out first; fail() buzzes then.
        _next = PausableTimer(pause, fail);
        notify();
      } else {
        fail();
      }
      return;
    }
    feedback?.wrong();
    _next = PausableTimer(pause, _advance);
    notify();
  }

  /// The reveal for a [verdict] [error] percent off, [window] wide.
  static RevealTier tierOf(SplitVerdict verdict, double error, double window) {
    const slack = 1e-9;
    return switch (verdict) {
      SplitVerdict.bullseye => RevealTier.perfect,
      SplitVerdict.sharp => RevealTier.close,
      SplitVerdict.miss when error <= window + nearMissMargin + slack =>
        RevealTier.close,
      _ => RevealTier.normal,
    };
  }

  /// How long [outcome] stays on the card before the next question (or,
  /// on the last strike, before the run goes down after a close reveal).
  static Duration pauseFor(SplitOutcome outcome) => switch (outcome.tier) {
    RevealTier.perfect => perfectPause,
    RevealTier.close => closePause,
    RevealTier.normal => outcome.verdict.isHit ? hitPause : missPause,
  };

  void _advance() {
    if (isPlaying) {
      _nextQuestion();
    }
  }

  void _cancelTimers() {
    _next?.cancel();
    _countdown?.cancel();
  }

  @override
  void onStart() => _show();

  /// The countdown and the next-question delay keep their remaining time.
  @override
  void onPause() {
    aim.value = null;
    _next?.pause();
    _countdown?.pause();
  }

  @override
  void onResume() {
    _next?.resume();
    _countdown?.resume();
  }

  @override
  void onDown() => _cancelTimers();

  /// A fresh target at the same question number, one strike left.
  @override
  void onRevive() {
    _cancelTimers();
    strikesLeft = 1;
    question = generate(number, random, previous: target);
    _show();
  }

  @override
  void onFinish() => _cancelTimers();

  @override
  void dispose() {
    _cancelTimers();
    aim.dispose();
    super.dispose();
  }
}
