import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/painting.dart';

import '../../models/game.dart';
import '../round_engine.dart';

/// READ: set the tape to the angle on the card. DRAW: aim the second arm at
/// the number shown.
enum AngleRule { read, draw }

/// What the card shows. Angles are in degrees, counter-clockwise from the
/// +x axis (screen right), like a maths protractor.
enum AngleKind {
  /// Base arm along the x-axis pointing right.
  flat,

  /// Base arm straight up; the second arm on either side.
  vertical,

  /// Two full lines cross in an X; the gold arc marks one of the 4 angles.
  crossed,

  /// The smaller angle between a clock's hands.
  clock,

  /// A filled wedge (from 12 o'clock clockwise on Medium, any way on Hard).
  pie,

  /// Compass bearing: clockwise from north, 0–359.
  bearing,

  /// Two arms at a random rotation (Hard).
  rays,

  /// One marked corner of a triangle (Hard).
  triangle,

  /// DRAW from a flat base arm (Easy).
  drawFlat,

  /// DRAW on a clock face: set the hand, clockwise from 12 (Medium).
  drawClock,

  /// DRAW from a base arm at a random rotation (Hard).
  drawRotated,

  /// Medium, every 10th question: point the compass needle at a heading.
  compassRound;

  AngleRule get rule =>
      index >= drawFlat.index ? AngleRule.draw : AngleRule.read;
}

/// One step of a difficulty's ladder, from question [from] on.
class AngleStage {
  const AngleStage(
    this.from,
    this.window, {
    required this.scenes,
    this.timer,
    this.draw,
    this.rotated = false,
    this.reflex = false,
    this.tricks = false,
  });

  final int from;

  /// A hit is an error (rounded) of at most this many degrees.
  final int window;

  /// The READ scenes picked from at random.
  final List<AngleKind> scenes;

  /// Per-question countdown; null for none.
  final Duration? timer;

  /// The DRAW scene, when this stage mixes in DRAW questions.
  final AngleKind? draw;

  /// Crossings and pies at a random rotation (Hard).
  final bool rotated;

  /// Reflex angles (190–350°, the big side marked) mixed in.
  final bool reflex;

  /// Short arms, dashed arms and decoy arcs mixed in.
  final bool tricks;
}

/// The question on the card.
class AngleQuestion {
  const AngleQuestion({
    required this.kind,
    required this.answer,
    required this.vertex,
    required this.base,
    this.dir = 1,
    this.armLength = 0.4,
    double? secondArmLength,
    this.dashed = false,
    this.decoy = false,
    this.hour,
    this.minute,
  }) : secondArmLength = secondArmLength ?? armLength;

  final AngleKind kind;

  /// The true angle in whole degrees.
  final int answer;

  /// Where the arms meet, in card units (0–1, y down).
  final Offset vertex;

  /// Direction of the base arm (degrees, counter-clockwise from +x).
  final double base;

  /// 1 when the angle opens counter-clockwise from [base], −1 clockwise
  /// (clock faces and compass bearings).
  final int dir;

  /// Arm lengths in card units.
  final double armLength;
  final double secondArmLength;

  /// Tricks (Hard 31+): dashed arms and a dim arc on the wrong side.
  final bool dashed;
  final bool decoy;

  /// The time shown on a [AngleKind.clock].
  final int? hour;
  final int? minute;

  AngleRule get rule => kind.rule;

  /// Screen direction (degrees, counter-clockwise from +x) of an arm
  /// [degrees] away from the base, the way this question measures.
  double armAt(num degrees) => base + dir * degrees;

  /// The point [length] card units from the vertex at screen angle [deg].
  Offset point(double deg, double length) {
    final r = deg * pi / 180;
    return vertex + Offset(cos(r) * length, -sin(r) * length);
  }

  /// The compass round's target, e.g. "FACE SE · 135°".
  String get heading {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return 'FACE ${names[(answer / 45).round() % 8]} · $answer°';
  }
}

/// How a locked answer went.
enum AngleGrade {
  bullseye('BULLSEYE'),
  sharp('SHARP'),
  hit('HIT'),
  miss('MISS'),
  time('TIME');

  const AngleGrade(this.label);
  final String label;

  bool get isHit => index <= hit.index;

  /// Points on top of the base 10.
  int get bonus => switch (this) {
    bullseye => 10,
    sharp => 5,
    _ => 0,
  };
}

/// How the board reveals an answer, and how long the engine waits for it.
enum RevealTier {
  /// A bullseye (≤1°): the arms merge into one glowing gold line.
  perfect,

  /// A sharp hit (≤3°) or a near miss: a slow-motion sweep in a zoomed
  /// loupe that shows the small gap.
  close,

  /// Everything else: the plain 700 ms sweep.
  normal,
}

/// A locked (or timed-out) answer.
class AngleOutcome {
  const AngleOutcome({
    required this.grade,
    required this.guess,
    required this.error,
    this.tier = RevealTier.normal,
  });

  final AngleGrade grade;

  /// How the board reveals it (see [AngleSenseEngine.tierFor]).
  final RevealTier tier;

  /// A miss shown in the loupe: just outside the window.
  bool get nearMiss => tier == RevealTier.close && !grade.isHit;

  /// What the player set; null on a DRAW timeout before any aim.
  final int? guess;

  /// Signed shortest error (guess − answer), −179..180; null with no guess.
  final int? error;

  /// "SHARP −1°", "HIT +2°", "BULLSEYE 0°", "MISS +14°" or "TIME".
  String get label {
    final e = error;
    if (grade == AngleGrade.time || e == null) {
      return grade.label;
    }
    final sign = e > 0
        ? '+'
        : e < 0
        ? '−'
        : '';
    return '${grade.label} $sign${e.abs()}°';
  }

  /// The board's verdict chip: "PERFECT 0°" for a bullseye, "SO CLOSE +10°"
  /// for a near miss, else [label].
  String get chip {
    final e = error;
    if (e == null) {
      return label;
    }
    final signed =
        '${e > 0
            ? '+'
            : e < 0
            ? '−'
            : ''}${e.abs()}°';
    if (tier == RevealTier.perfect) {
      return 'PERFECT $signed';
    }
    if (nearMiss) {
      return 'SO CLOSE $signed';
    }
    return label;
  }
}

/// Angle Sense: read an angle off the card (READ) or draw one (DRAW). A miss
/// or a timeout breaks one of [maxStrikes] shields; losing the last ends
/// the run. A revive gives back exactly one.
/// Each difficulty opens flat → vertical → crossed, then ramps by question
/// number (see [ladder]).
class AngleSenseEngine extends RoundEngine {
  AngleSenseEngine({
    required super.difficulty,
    super.previousBest,
    super.feedback,
    super.random,
  }) : super(game: GameId.angleSense) {
    question = generate(number, difficulty, random);
  }

  /// Shields per run (the field names keep the older "strikes").
  static const maxStrikes = 2;
  static const minRuleRun = 2;
  static const drawChance = 0.35;
  static const compassWindow = 12;
  static const basePoints = 10;

  /// The board's plain reveal sweep ([RevealTier.normal]); the pauses below
  /// come after the reveal (see [revealFor]).
  static const revealDuration = Duration(milliseconds: 700);

  /// [RevealTier.perfect]: the arms merge into a glowing gold line.
  static const perfectReveal = Duration(milliseconds: 900);

  /// [RevealTier.close]: the slow-motion sweep, then the loupe holds.
  static const closeSweep = Duration(milliseconds: 1600);
  static const closeHold = Duration(milliseconds: 400);

  /// A miss up to this far past the window still gets the slow motion.
  static const nearMissMargin = 3;

  static const hitPause = Duration(milliseconds: 650);
  static const missPause = Duration(milliseconds: 1100);

  static const _easy = [
    AngleStage(1, 8, scenes: [AngleKind.flat]),
    AngleStage(8, 7, scenes: [AngleKind.vertical]),
    AngleStage(15, 6, scenes: [AngleKind.crossed]),
    AngleStage(26, 6, scenes: _basics, draw: AngleKind.drawFlat),
    AngleStage(41, 5, scenes: _basics, draw: AngleKind.drawFlat),
  ];
  static const _basics = [
    AngleKind.flat,
    AngleKind.vertical,
    AngleKind.crossed,
  ];

  static const _medium = [
    AngleStage(1, 8, scenes: [AngleKind.flat]),
    AngleStage(4, 8, scenes: [AngleKind.vertical]),
    AngleStage(7, 7, scenes: [AngleKind.crossed]),
    AngleStage(10, 7, scenes: _dials),
    AngleStage(13, 7, scenes: _dials, timer: Duration(seconds: 8)),
    AngleStage(
      21,
      6,
      scenes: _dials,
      timer: Duration(seconds: 7),
      draw: AngleKind.drawClock,
    ),
    AngleStage(
      31,
      6,
      scenes: _dials,
      timer: Duration(seconds: 6),
      draw: AngleKind.drawClock,
    ),
    AngleStage(
      41,
      5,
      scenes: _dials,
      timer: Duration(milliseconds: 5500),
      draw: AngleKind.drawClock,
    ),
  ];
  static const _dials = [AngleKind.clock, AngleKind.pie, AngleKind.bearing];

  static const _hard = [
    AngleStage(1, 9, scenes: [AngleKind.flat], timer: Duration(seconds: 6)),
    AngleStage(3, 9, scenes: [AngleKind.vertical], timer: Duration(seconds: 6)),
    AngleStage(5, 9, scenes: [AngleKind.crossed], timer: Duration(seconds: 6)),
    AngleStage(
      7,
      8,
      scenes: _any,
      timer: Duration(milliseconds: 5500),
      rotated: true,
    ),
    AngleStage(
      13,
      8,
      scenes: _any,
      timer: Duration(seconds: 5),
      rotated: true,
      draw: AngleKind.drawRotated,
    ),
    AngleStage(
      21,
      7,
      scenes: _any,
      timer: Duration(milliseconds: 4500),
      rotated: true,
      draw: AngleKind.drawRotated,
      reflex: true,
    ),
    AngleStage(
      31,
      7,
      scenes: _any,
      timer: Duration(seconds: 4),
      rotated: true,
      draw: AngleKind.drawRotated,
      reflex: true,
      tricks: true,
    ),
    AngleStage(
      51,
      6,
      scenes: _any,
      timer: Duration(seconds: 4),
      rotated: true,
      draw: AngleKind.drawRotated,
      reflex: true,
      tricks: true,
    ),
  ];
  static const _any = [
    AngleKind.rays,
    AngleKind.crossed,
    AngleKind.pie,
    AngleKind.triangle,
  ];

  /// Each difficulty's stages, in question order.
  static List<AngleStage> ladder(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => _easy,
    Difficulty.medium => _medium,
    Difficulty.hard => _hard,
  };

  /// How long the board's sweep animates for [tier].
  static Duration sweepFor(RevealTier tier) => switch (tier) {
    RevealTier.perfect => perfectReveal,
    RevealTier.close => closeSweep,
    RevealTier.normal => revealDuration,
  };

  /// The whole reveal for [tier]; the next question waits this plus the
  /// hit or miss pause.
  static Duration revealFor(RevealTier tier) => switch (tier) {
    RevealTier.close => closeSweep + closeHold,
    _ => sweepFor(tier),
  };

  /// Bullseye → perfect; sharp, or a miss within [window] +
  /// [nearMissMargin] → close; anything else (and a timeout) → normal.
  static RevealTier tierFor(AngleGrade grade, int? error, int window) =>
      switch (grade) {
        AngleGrade.bullseye => RevealTier.perfect,
        AngleGrade.sharp => RevealTier.close,
        AngleGrade.miss
            when error != null && error.abs() <= window + nearMissMargin =>
          RevealTier.close,
        _ => RevealTier.normal,
      };

  static AngleStage stageFor(Difficulty difficulty, int number) =>
      ladder(difficulty).lastWhere((stage) => number >= stage.from);

  /// Medium, every 10th question: a compass dial, a wider window, no timer.
  static bool compassRoundAt(Difficulty difficulty, int number) =>
      difficulty == Difficulty.medium && number % 10 == 0;

  static int windowFor(Difficulty difficulty, int number) =>
      compassRoundAt(difficulty, number)
      ? compassWindow
      : stageFor(difficulty, number).window;

  static Duration? timeLimitFor(Difficulty difficulty, int number) =>
      compassRoundAt(difficulty, number)
      ? null
      : stageFor(difficulty, number).timer;

  /// [a] normalised to 0 ≤ a < 360.
  static double norm(num a) => ((a % 360) + 360) % 360;

  /// Shortest signed difference [guess] − [truth], in (−180, 180].
  static double signedError(num guess, num truth) {
    final d = norm(guess - truth);
    return d > 180 ? d - 360 : d;
  }

  /// Shortest angular difference: 359° vs 1° is 2°.
  static double angleError(num a, num b) => signedError(a, b).abs();

  late AngleQuestion question;
  int number = 1;

  /// Shields left this run (gold shields in the card's corner).
  int strikesLeft = maxStrikes;

  /// READ: the tape's value, 0–360. Kept from question to question.
  int guess = 90;

  /// DRAW: where the player aimed the arm (0–359), null until they do.
  int? drawGuess;

  /// Set when the answer locks (or time runs out); cleared by the next
  /// question.
  AngleOutcome? outcome;

  /// True when the current question shows a different rule than the last.
  bool ruleChanged = false;

  /// When the current question appeared (package:clock time).
  DateTime? questionStartedAt;

  PausableTimer? _next;
  PausableTimer? _countdown;

  // The READ/DRAW run, not counting compass rounds.
  AngleRule _rule = AngleRule.read;
  int _ruleRun = minRuleRun;

  bool get locked => outcome != null || !isPlaying;
  AngleRule get rule => question.rule;
  AngleStage get stage => stageFor(difficulty, number);
  bool get isCompassRound => question.kind == AngleKind.compassRound;
  int get window => isCompassRound ? compassWindow : stage.window;

  /// The current question's countdown; null when it has none.
  Duration? get timeLimit => timeLimitFor(difficulty, number);

  /// What's left of the countdown (frozen while paused); null when none is
  /// running.
  Duration? get timeLeft {
    final countdown = _countdown;
    return countdown != null && countdown.isActive ? countdown.remaining : null;
  }

  /// Lock is allowed: DRAW needs an aim first.
  bool get canLock => !locked && (rule == AngleRule.read || drawGuess != null);

  /// The question for [number]. [previousRule] and [ruleRun] (questions
  /// shown under it so far) keep each rule for at least [minRuleRun]
  /// questions once DRAW mixes in.
  static AngleQuestion generate(
    int number,
    Difficulty difficulty,
    Random random, {
    AngleRule previousRule = AngleRule.read,
    int ruleRun = minRuleRun,
  }) {
    int ri(int a, int b) => a + random.nextInt(b - a + 1);
    T any<T>(List<T> list) => list[random.nextInt(list.length)];

    if (compassRoundAt(difficulty, number)) {
      // TODO: phone heading via a compass plugin. For now the player drags
      // the needle on the dial.
      final offset = random.nextBool() ? 0 : ri(-15, 15);
      return AngleQuestion(
        kind: AngleKind.compassRound,
        answer: norm(ri(1, 7) * 45 + offset).round(),
        vertex: const Offset(0.5, 0.5),
        base: 90,
        dir: -1,
        armLength: 0.3,
      );
    }

    final stage = stageFor(difficulty, number);
    var rule = AngleRule.read;
    if (stage.draw != null) {
      final wanted = random.nextDouble() < drawChance
          ? AngleRule.draw
          : AngleRule.read;
      rule = ruleRun < minRuleRun ? previousRule : wanted;
    }
    if (rule == AngleRule.draw) {
      return _draw(stage.draw!, stage, ri);
    }
    return _read(any(stage.scenes), stage, random, ri);
  }

  static AngleQuestion _draw(
    AngleKind kind,
    AngleStage stage,
    int Function(int, int) ri,
  ) {
    switch (kind) {
      case AngleKind.drawClock:
        return AngleQuestion(
          kind: kind,
          answer: ri(10, 350),
          vertex: const Offset(0.5, 0.5),
          base: 90,
          dir: -1,
          armLength: 0.34,
        );
      case AngleKind.drawRotated:
        final base = ri(0, 359).toDouble();
        final reflex = stage.reflex && ri(1, 4) == 1;
        final answer = reflex ? ri(190, 345) : ri(15, 165);
        // The vertex sits off-centre away from a fixed side of the base arm
        // (not the answer's side), so its position gives nothing away.
        return AngleQuestion(
          kind: kind,
          answer: answer,
          vertex: reflex ? const Offset(0.5, 0.5) : _offCentre(base + 90),
          base: base,
          armLength: reflex ? 0.36 : 0.4,
        );
      default:
        return AngleQuestion(
          kind: AngleKind.drawFlat,
          answer: ri(15, 165),
          vertex: const Offset(0.5, 0.66),
          base: 0,
        );
    }
  }

  /// A vertex 0.2 card units from the centre, opposite [towards], so arms
  /// fanning around [towards] stay on the card.
  static Offset _offCentre(double towards) {
    final r = towards * pi / 180;
    return Offset(0.5 - 0.2 * cos(r), 0.5 + 0.2 * sin(r));
  }

  static AngleQuestion _read(
    AngleKind kind,
    AngleStage stage,
    Random random,
    int Function(int, int) ri,
  ) {
    const centre = Offset(0.5, 0.5);
    switch (kind) {
      case AngleKind.flat:
        return AngleQuestion(
          kind: kind,
          answer: ri(10, 170),
          vertex: const Offset(0.5, 0.66),
          base: 0,
        );
      case AngleKind.vertical:
        return AngleQuestion(
          kind: kind,
          answer: ri(10, 170),
          vertex: centre,
          base: 90,
          dir: random.nextBool() ? 1 : -1,
          armLength: 0.38,
        );
      case AngleKind.crossed:
        // Lines at [line] and [line] + b; mark one of the 4 angles.
        final line = stage.rotated ? ri(0, 179) : (random.nextBool() ? 0 : 90);
        final b = ri(20, 160);
        final quadrant = random.nextInt(4);
        return AngleQuestion(
          kind: kind,
          answer: quadrant.isEven ? b : 180 - b,
          vertex: centre,
          base: norm(
            line + const [0, 0, 180, 180][quadrant] + (quadrant.isOdd ? b : 0),
          ),
          armLength: 0.42,
        );
      case AngleKind.clock:
        while (true) {
          final hour = ri(1, 12);
          final minute = ri(0, 5) * 10;
          final hourAt = 90 - (hour % 12) * 30 - minute / 2;
          final minuteAt = 90 - minute * 6;
          final d = norm(minuteAt - hourAt);
          final small = d > 180 ? 360 - d : d;
          if (small < 10 || small > 175) {
            continue;
          }
          return AngleQuestion(
            kind: kind,
            answer: small.round(),
            vertex: centre,
            base: d > 180 ? norm(minuteAt) : norm(hourAt),
            armLength: 0.3,
            hour: hour,
            minute: minute,
          );
        }
      case AngleKind.pie:
        if (!stage.rotated) {
          return AngleQuestion(
            kind: kind,
            answer: ri(15, 330),
            vertex: centre,
            base: 90,
            dir: -1,
            armLength: 0.34,
          );
        }
        final reflex = stage.reflex && random.nextDouble() < 0.35;
        return AngleQuestion(
          kind: kind,
          answer: reflex ? ri(190, 330) : ri(12, 170),
          vertex: centre,
          base: ri(0, 359).toDouble(),
          armLength: 0.34,
        );
      case AngleKind.bearing:
        return AngleQuestion(
          kind: kind,
          answer: ri(5, 355),
          vertex: centre,
          base: 90,
          dir: -1,
          armLength: 0.28,
        );
      case AngleKind.triangle:
        while (true) {
          final answer = ri(25, 140);
          final base = ri(0, 359).toDouble();
          final l1 = ri(30, 46) / 100;
          final l2 = ri(30, 46) / 100;
          final u1 = _unit(base) * l1;
          final u2 = _unit(base + answer) * l2;
          // Centre the triangle's centroid on the card.
          final vertex = centre - (u1 + u2) / 3;
          final corners = [vertex, vertex + u1, vertex + u2];
          if (corners.every((p) => _inside(p, 0.06))) {
            return AngleQuestion(
              kind: kind,
              answer: answer,
              vertex: vertex,
              base: base,
              armLength: l1,
              secondArmLength: l2,
            );
          }
        }
      default:
        // Rays at a random rotation.
        final base = ri(0, 359).toDouble();
        final reflex = stage.reflex && random.nextDouble() < 0.35;
        final answer = reflex ? ri(190, 350) : ri(5, 175);
        final tricky = stage.tricks;
        return AngleQuestion(
          kind: AngleKind.rays,
          answer: answer,
          vertex: reflex ? centre : _offCentre(base + answer / 2),
          base: base,
          armLength: reflex ? 0.36 : 0.4,
          secondArmLength: tricky && !reflex && random.nextBool() ? 0.2 : null,
          dashed: tricky && random.nextDouble() < 0.35,
          decoy: tricky && random.nextDouble() < 0.4,
        );
    }
  }

  static Offset _unit(double deg) {
    final r = deg * pi / 180;
    return Offset(cos(r), -sin(r));
  }

  static bool _inside(Offset p, double margin) =>
      p.dx >= margin &&
      p.dx <= 1 - margin &&
      p.dy >= margin &&
      p.dy <= 1 - margin;

  void _setQuestion(AngleQuestion next) {
    ruleChanged = next.rule != question.rule;
    if (next.kind != AngleKind.compassRound) {
      _ruleRun = next.rule == _rule ? _ruleRun + 1 : 1;
      _rule = next.rule;
    }
    question = next;
  }

  /// Clears the last answer and (re)starts the question's countdown.
  void _showQuestion() {
    outcome = null;
    drawGuess = null;
    questionStartedAt = clock.now();
    _next?.cancel();
    _countdown?.cancel();
    final limit = timeLimit;
    _countdown = limit == null ? null : PausableTimer(limit, _timeUp);
    notify();
  }

  void _nextQuestion() {
    if (!isPlaying) {
      return;
    }
    number++;
    _setQuestion(
      generate(
        number,
        difficulty,
        random,
        previousRule: _rule,
        ruleRun: _ruleRun,
      ),
    );
    _showQuestion();
  }

  /// READ: set the tape to [degrees] (clamped to 0–360).
  void setGuess(int degrees) {
    if (locked || rule != AngleRule.read) {
      return;
    }
    final value = degrees.clamp(0, 360);
    if (value != guess) {
      guess = value;
      notify();
    }
  }

  /// DRAW: aim the arm at [degrees] from the base (the way the question
  /// measures).
  void aim(double degrees) {
    if (locked || rule != AngleRule.draw) {
      return;
    }
    final value = norm(degrees.round()).round();
    if (value != drawGuess) {
      drawGuess = value;
      notify();
    }
  }

  /// The −1 / +1 buttons.
  void nudge(int delta) {
    if (locked) {
      return;
    }
    if (rule == AngleRule.read) {
      setGuess(guess + delta);
    } else if (drawGuess != null) {
      drawGuess = norm(drawGuess! + delta).round();
      notify();
    }
  }

  void lock() {
    if (!canLock) {
      return;
    }
    _settle(timedOut: false);
  }

  void _timeUp() {
    if (!isPlaying || outcome != null) {
      return;
    }
    _settle(timedOut: true);
  }

  void _settle({required bool timedOut}) {
    _countdown?.cancel();
    final answer = rule == AngleRule.read ? guess : drawGuess;
    final error = answer == null
        ? null
        : signedError(answer, question.answer).round();
    final grade = timedOut || error == null
        ? AngleGrade.time
        : error.abs() > window
        ? AngleGrade.miss
        : error.abs() <= 1
        ? AngleGrade.bullseye
        : error.abs() <= 3
        ? AngleGrade.sharp
        : AngleGrade.hit;
    final tier = tierFor(grade, error, window);
    outcome = AngleOutcome(
      grade: grade,
      guess: answer,
      error: error,
      tier: tier,
    );
    // The question timer is already stopped, so a longer reveal costs no
    // play time.
    final reveal = revealFor(tier);

    if (grade.isHit) {
      scoreCorrect(basePoints + grade.bonus);
      _next = PausableTimer(reveal + hitPause, _nextQuestion);
      return;
    }
    strikesLeft = max(0, strikesLeft - 1);
    if (strikesLeft > 0) {
      breakStreak();
      feedback?.wrong();
      _next = PausableTimer(reveal + missPause, _nextQuestion);
    } else {
      // The last shield: let the reveal play, then go down (fail() buzzes).
      _next = PausableTimer(reveal + missPause, fail);
    }
    notify();
  }

  void _cancelTimers() {
    _next?.cancel();
    _countdown?.cancel();
  }

  @override
  void onStart() => _showQuestion();

  /// The countdown and the next-question delay keep their remaining time.
  @override
  void onPause() {
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

  /// A fresh question at the same number (same stage and rule) and one
  /// shield left.
  @override
  void onRevive() {
    strikesLeft = 1;
    _setQuestion(
      generate(number, difficulty, random, previousRule: _rule, ruleRun: 0),
    );
    _showQuestion();
  }

  @override
  void onFinish() => _cancelTimers();

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
