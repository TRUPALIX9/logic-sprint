import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/guess_color/guess_color_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

void main() {
  GuessColorEngine engine([int seed = 1]) =>
      GuessColorEngine(difficulty: Difficulty.medium, random: Random(seed));

  InkColor wrongColor(GuessColorEngine e) =>
      InkColor.values.firstWhere((color) => color != e.item.target);

  List<InkColor> fills(GuessItem item) => [
    for (final button in item.buttons) button.fill,
  ];

  /// Items for words [from]..[to], chaining the rule like the engine does.
  List<GuessItem> run(int from, int to, Random random) {
    var rule = GuessRule.color;
    var ruleRun = GuessColorEngine.minRuleRun;
    final items = <GuessItem>[];
    for (var n = from; n <= to; n++) {
      final item = GuessColorEngine.generate(
        n,
        random,
        previousRule: rule,
        ruleRun: ruleRun,
      );
      ruleRun = item.ruleChanged ? 1 : ruleRun + 1;
      rule = item.rule;
      items.add(item);
    }
    return items;
  }

  /// Items for words [from]..[to] across many seeds.
  List<GuessItem> items(int from, int to) => [
    for (var seed = 0; seed < 40; seed++) ...run(from, to, Random(seed)),
  ];

  /// Plays correct picks until word [n] is showing.
  void advanceTo(GuessColorEngine e, FakeAsync async, int n) {
    while (e.number < n) {
      e.pick(e.item.target);
      async.elapse(const Duration(milliseconds: 250));
    }
  }

  group('stages', () {
    test('ramp by word number', () {
      const expected = {
        1: GuessStage.classic,
        5: GuessStage.classic,
        6: GuessStage.shuffled,
        12: GuessStage.shuffled,
        13: GuessStage.timed,
        20: GuessStage.timed,
        21: GuessStage.ruleSwap,
        30: GuessStage.ruleSwap,
        31: GuessStage.mislabeled,
        40: GuessStage.mislabeled,
        41: GuessStage.neutral,
        500: GuessStage.neutral,
      };
      expected.forEach((number, stage) {
        expect(GuessStage.of(number), stage, reason: 'word $number');
      });
    });

    test('always 4 buttons, one per color', () {
      for (final item in items(1, 80)) {
        expect(fills(item), hasLength(4));
        expect(fills(item).toSet(), InkColor.values.toSet());
      }
    });

    test('congruent words only in 1–5, about 1 in 4', () {
      final early = items(1, 5);
      final share = early.where((item) => item.congruent).length / early.length;
      expect(share, inInclusiveRange(0.15, 0.35));
      for (final item in items(6, 80)) {
        expect(item.congruent, isFalse);
      }
    });

    test('order is fixed through word 5, then reshuffles', () {
      for (final item in items(1, 5)) {
        expect(fills(item), InkColor.values);
      }
      final reordered = items(
        6,
        12,
      ).where((item) => !listEquals(fills(item), InkColor.values));
      expect(reordered, isNotEmpty);
    });

    test('countdown starts at 3.0 s on word 13 and floors at 1.0 s', () {
      expect(GuessColorEngine.timeLimitFor(12), isNull);
      expect(
        GuessColorEngine.timeLimitFor(13),
        const Duration(milliseconds: 3000),
      );
      expect(
        GuessColorEngine.timeLimitFor(14),
        const Duration(milliseconds: 2950),
      );
      expect(GuessColorEngine.timeLimitFor(53), const Duration(seconds: 1));
      expect(GuessColorEngine.timeLimitFor(400), const Duration(seconds: 1));
    });

    test('rule is COLOR before word 21', () {
      for (final item in items(1, 20)) {
        expect(item.rule, GuessRule.color);
        expect(item.ruleChanged, isFalse);
        expect(item.target, item.ink);
      }
    });

    test('from word 21 the rule swaps, about 35% TEXT', () {
      final swapped = items(21, 80);
      final share =
          swapped.where((item) => item.rule == GuessRule.text).length /
          swapped.length;
      expect(share, inInclusiveRange(0.2, 0.45));
    });

    test('rule TEXT targets the named color', () {
      final wordTurns = items(
        21,
        80,
      ).where((item) => item.rule == GuessRule.text);
      expect(wordTurns, isNotEmpty);
      for (final item in wordTurns) {
        expect(item.kind, ItemKind.word);
        expect(item.target, item.word);
        expect(item.target, isNot(item.ink));
      }
    });

    test('ruleChanged marks each flip; flips are at least 2 words apart', () {
      for (var seed = 0; seed < 40; seed++) {
        final sequence = run(1, 120, Random(seed));
        int? lastFlip;
        for (var i = 0; i < sequence.length; i++) {
          final previous = i == 0 ? GuessRule.color : sequence[i - 1].rule;
          expect(sequence[i].ruleChanged, sequence[i].rule != previous);
          if (sequence[i].ruleChanged) {
            if (lastFlip != null) {
              expect(i - lastFlip, greaterThanOrEqualTo(2));
            }
            lastFlip = i;
          }
        }
      }
    });

    test('labels match fills through word 30, then never', () {
      for (final item in items(1, 30)) {
        for (final button in item.buttons) {
          expect(button.label, button.fill);
        }
      }
      for (final item in items(31, 80)) {
        expect(
          item.buttons.map((b) => b.label).toSet(),
          InkColor.values.toSet(),
        );
        for (final button in item.buttons) {
          expect(button.label, isNot(button.fill));
        }
      }
    });

    test('neutral items only from word 41, only on COLOR turns', () {
      for (final item in items(1, 40)) {
        expect(item.kind, ItemKind.word);
      }
      final later = items(41, 120);
      final neutral = later.where((item) => item.kind != ItemKind.word);
      expect(neutral, isNotEmpty);
      expect(neutral.where((item) => item.kind == ItemKind.shape), isNotEmpty);
      for (final item in neutral) {
        expect(item.rule, GuessRule.color);
        expect(item.target, item.ink);
        expect(item.word, isNull);
        if (item.kind == ItemKind.shape) {
          expect(item.shape, isNotNull);
          expect(item.text, isNull);
        } else {
          expect(GuessColorEngine.neutralWords, contains(item.neutral));
          expect(item.text, item.neutral);
        }
      }
      final colorTurns = later.where((item) => item.rule == GuessRule.color);
      final share = neutral.length / colorTurns.length;
      expect(share, inInclusiveRange(0.2, 0.4));
    });

    test('distraction params are off before word 41 and in range after', () {
      for (final item in items(1, 40)) {
        expect(item.rotationDegrees, 0);
        expect(item.pulse, isFalse);
        expect(item.shake, isFalse);
      }
      final later = items(41, 120);
      for (final item in later) {
        expect(item.rotationDegrees, inInclusiveRange(-10, 10));
      }
      expect(later.where((item) => item.rotationDegrees != 0), isNotEmpty);
      expect(later.where((item) => item.pulse), isNotEmpty);
      final shakes = later.where((item) => item.shake).length / later.length;
      expect(shakes, inInclusiveRange(0.1, 0.3));
    });
  });

  test('difficulty is ignored', () {
    final easy = GuessColorEngine(
      difficulty: Difficulty.easy,
      random: Random(5),
    );
    final hard = GuessColorEngine(
      difficulty: Difficulty.hard,
      random: Random(5),
    );
    expect(easy.item.word, hard.item.word);
    expect(easy.item.ink, hard.item.ink);
    expect(fills(easy.item), fills(hard.item));
    easy.dispose();
    hard.dispose();
  });

  test('picks are ignored before the run starts', () {
    final e = engine();
    e.pick(e.item.target);
    expect(e.correct, 0);
    expect(e.picked, isNull);
    e.dispose();
  });

  test('correct pick scores, locks, then shows the next word', () {
    fakeAsync((async) {
      final e = engine()..start();
      e.pick(e.item.target);
      e.pick(e.item.target);
      expect(e.correct, 1);
      expect(e.score, 10);
      expect(e.locked, isTrue);
      async.elapse(const Duration(milliseconds: 200));
      expect(e.number, 1);
      async.elapse(const Duration(milliseconds: 100));
      expect(e.number, 2);
      expect(e.picked, isNull);
      expect(e.locked, isFalse);
      e.dispose();
    });
  });

  test('no countdown before word 13', () {
    fakeAsync((async) {
      final e = engine()..start();
      expect(e.timeLimit, isNull);
      async.elapse(const Duration(minutes: 1));
      expect(e.state, RunState.playing);
      e.dispose();
    });
  });

  test('running out of time puts the run down', () {
    fakeAsync((async) {
      final e = engine()..start();
      advanceTo(e, async, 13);
      expect(e.timeLimit, const Duration(seconds: 3));
      expect(e.wordStartedAt, clock.now());
      async.elapse(const Duration(milliseconds: 2900));
      expect(e.state, RunState.playing);
      async.elapse(const Duration(milliseconds: 200));
      expect(e.state, RunState.down);
      expect(e.timedOut, isTrue);
      expect(e.locked, isTrue);
      e.dispose();
    });
  });

  test('a pick stops the countdown', () {
    fakeAsync((async) {
      final e = engine()..start();
      advanceTo(e, async, 13);
      e.pick(e.item.target);
      async.elapse(const Duration(milliseconds: 250));
      expect(e.number, 14);
      async.elapse(const Duration(milliseconds: 2900));
      expect(e.state, RunState.playing);
      e.dispose();
    });
  });

  test('wrong pick puts the run down and keeps the feedback', () {
    fakeAsync((async) {
      final e = engine()..start();
      final color = wrongColor(e);
      e.pick(color);
      expect(e.state, RunState.down);
      expect(e.picked, color);
      expect(e.timedOut, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(e.number, 1);
      e.pick(e.item.target);
      expect(e.correct, 0);
      e.dispose();
    });
  });

  test('revive shows a fresh word and restarts the countdown', () {
    fakeAsync((async) {
      final e = engine()..start();
      advanceTo(e, async, 13);
      final failed = e.item;
      e.pick(wrongColor(e));
      async.elapse(const Duration(seconds: 10));
      expect(e.state, RunState.down);
      e.revive();
      expect(e.state, RunState.playing);
      expect(e.number, 13);
      expect(e.item, isNot(same(failed)));
      expect(e.picked, isNull);
      expect(e.wordStartedAt, clock.now());
      async.elapse(const Duration(milliseconds: 2900));
      expect(e.state, RunState.playing);
      async.elapse(const Duration(milliseconds: 200));
      expect(e.state, RunState.down);
      expect(e.timedOut, isTrue);
      e.dispose();
    });
  });

  test('revive then correct picks keep scoring', () {
    fakeAsync((async) {
      final e = engine()..start();
      e.pick(wrongColor(e));
      e.revive();
      e.pick(e.item.target);
      expect(e.correct, 1);
      e.dispose();
    });
  });

  test('finish gives a result timed without the down time', () {
    fakeAsync((async) {
      final e = engine()..start();
      async.elapse(const Duration(seconds: 2));
      e.pick(wrongColor(e));
      async.elapse(const Duration(seconds: 5));
      e.revive();
      async.elapse(const Duration(seconds: 1));
      e.finish();
      async.elapse(const Duration(seconds: 1));
      expect(e.state, RunState.over);
      expect(e.result?.duration, const Duration(seconds: 3));
      e.pick(e.item.target);
      expect(e.correct, 0);
      e.dispose();
    });
  });
}
