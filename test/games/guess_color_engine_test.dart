import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/games/guess_color/guess_color_engine.dart';
import 'package:logic_sprint/games/round_engine.dart';
import 'package:logic_sprint/models/game.dart';

void main() {
  GuessColorEngine engine([int seed = 1]) =>
      GuessColorEngine(difficulty: Difficulty.medium, random: Random(seed));

  InkColor wrongColor(GuessColorEngine e) => e.item.buttons
      .map((button) => button.name)
      .firstWhere((name) => name != e.item.ink);

  /// Every word generated for [numbers] across a few seeds.
  Iterable<StroopWord> words(Iterable<int> numbers) sync* {
    for (var seed = 0; seed < 20; seed++) {
      final random = Random(seed);
      for (final number in numbers) {
        yield GuessColorEngine.generate(number, random);
      }
    }
  }

  Iterable<int> range(int from, int to) => [for (var n = from; n <= to; n++) n];

  List<InkColor> names(StroopWord item) => [
    for (final button in item.buttons) button.name,
  ];

  group('phases', () {
    test('ramp by word number', () {
      expect(GuessPhase.of(1), GuessPhase.warmUp);
      expect(GuessPhase.of(8), GuessPhase.warmUp);
      expect(GuessPhase.of(9), GuessPhase.full);
      expect(GuessPhase.of(18), GuessPhase.full);
      expect(GuessPhase.of(19), GuessPhase.shuffled);
      expect(GuessPhase.of(30), GuessPhase.shuffled);
      expect(GuessPhase.of(31), GuessPhase.mislabeled);
      expect(GuessPhase.of(45), GuessPhase.mislabeled);
      expect(GuessPhase.of(46), GuessPhase.tinted);
      expect(GuessPhase.of(500), GuessPhase.tinted);
    });

    test('palette sizes', () {
      expect(GuessPhase.warmUp.palette, hasLength(4));
      for (final phase in GuessPhase.values.skip(1)) {
        expect(phase.palette, hasLength(6));
      }
    });

    test('words 1–8: 4 honest buttons, sometimes congruent', () {
      var congruent = 0, total = 0;
      for (final item in words(range(1, 8))) {
        total++;
        expect(GuessPhase.warmUp.palette, contains(item.word));
        expect(GuessPhase.warmUp.palette, contains(item.ink));
        expect(names(item), GuessPhase.warmUp.palette);
        if (item.congruent) {
          congruent++;
        }
      }
      expect(congruent / total, inInclusiveRange(0.15, 0.35));
    });

    test('words 9+ never match their ink and offer every color once', () {
      for (final item in words(range(9, 80))) {
        expect(item.congruent, isFalse);
        expect(names(item).toSet(), InkColor.values.toSet());
        expect(names(item), hasLength(6));
      }
    });

    test('button order is fixed through word 18', () {
      for (final item in words(range(9, 18))) {
        expect(names(item), InkColor.values);
      }
    });

    test('button order reshuffles from word 19', () {
      final reordered = words(
        range(19, 80),
      ).where((item) => !listEquals(names(item), InkColor.values));
      expect(reordered, isNotEmpty);
    });

    test('through word 30 names keep their own color and swatch', () {
      for (final item in words(range(1, 30))) {
        for (final button in item.buttons) {
          expect(button.label, button.name);
          expect(button.tint, button.name);
          expect(button.swatch, isTrue);
        }
      }
    });

    test('words 31–45: names drawn in another color, no swatch', () {
      for (final item in words(range(31, 45))) {
        for (final button in item.buttons) {
          expect(button.label, isNot(button.name));
          expect(button.tint, button.name);
          expect(button.swatch, isFalse);
        }
      }
    });

    test('words 46+: tint differs from the name and the label color', () {
      for (final item in words(range(46, 80))) {
        for (final button in item.buttons) {
          expect(button.label, isNot(button.name));
          expect(button.tint, isNot(button.name));
          expect(button.tint, isNot(button.label));
        }
      }
    });

    test('every label color stays readable on every tint', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
      }

      for (final tint in InkColor.values) {
        final fill = Color.alphaBlend(tint.fill, LS.bg);
        for (final label in InkColor.values) {
          expect(
            contrast(label.color, fill),
            greaterThanOrEqualTo(4.5),
            reason: '${label.name} on ${tint.name}',
          );
        }
      }
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
    expect(names(easy.item), names(hard.item));
    easy.dispose();
    hard.dispose();
  });

  test('picks are ignored before the run starts', () {
    final e = engine();
    e.pick(e.item.ink);
    expect(e.correct, 0);
    expect(e.picked, isNull);
    e.dispose();
  });

  test('correct pick scores, locks, then shows the next word', () {
    fakeAsync((async) {
      final e = engine()..start();
      e.pick(e.item.ink);
      e.pick(e.item.ink);
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

  test('wrong pick puts the run down and keeps the feedback', () {
    fakeAsync((async) {
      final e = engine()..start();
      final color = wrongColor(e);
      e.pick(color);
      expect(e.state, RunState.down);
      expect(e.picked, color);
      expect(e.locked, isTrue);
      async.elapse(const Duration(seconds: 1));
      expect(e.number, 1);
      e.pick(e.item.ink);
      expect(e.correct, 0);
      e.dispose();
    });
  });

  test('revive shows a new word and picks work again', () {
    fakeAsync((async) {
      final e = engine()..start();
      e.pick(wrongColor(e));
      e.revive();
      expect(e.state, RunState.playing);
      expect(e.number, 2);
      expect(e.picked, isNull);
      e.pick(e.item.ink);
      expect(e.correct, 1);
      e.dispose();
    });
  });

  test('the run grows to 6 colors after word 8', () {
    fakeAsync((async) {
      final e = engine()..start();
      for (var i = 0; i < 8; i++) {
        expect(e.item.buttons, hasLength(4));
        e.pick(e.item.ink);
        async.elapse(const Duration(milliseconds: 300));
      }
      expect(e.number, 9);
      expect(e.phase, GuessPhase.full);
      expect(e.item.buttons, hasLength(6));
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
      e.pick(e.item.ink);
      expect(e.correct, 0);
      e.dispose();
    });
  });
}
