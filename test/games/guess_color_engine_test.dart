import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/guess_color/guess_color_engine.dart';
import 'package:logic_sprint/models/game.dart';

void main() {
  GuessColorEngine engine([int seed = 1]) =>
      GuessColorEngine(difficulty: Difficulty.medium, random: Random(seed));

  InkColor wrongColor(GuessColorEngine e) =>
      e.item.buttons.firstWhere((color) => color != e.item.ink);

  test('phase ramps by word number', () {
    expect(GuessPhase.of(1), GuessPhase.warmUp);
    expect(GuessPhase.of(8), GuessPhase.warmUp);
    expect(GuessPhase.of(9), GuessPhase.full);
    expect(GuessPhase.of(18), GuessPhase.full);
    expect(GuessPhase.of(19), GuessPhase.shuffled);
    expect(GuessPhase.of(60), GuessPhase.shuffled);
  });

  test('palette sizes per phase', () {
    expect(GuessPhase.warmUp.palette, hasLength(4));
    expect(GuessPhase.full.palette, hasLength(6));
    expect(GuessPhase.shuffled.palette, hasLength(6));
  });

  test('words 1–8 stay in 4 colors and are sometimes congruent', () {
    final palette = GuessPhase.warmUp.palette;
    final random = Random(3);
    var congruent = 0;
    for (var i = 0; i < 400; i++) {
      final item = GuessColorEngine.generate(1 + i % 8, random);
      expect(palette, contains(item.word));
      expect(palette, contains(item.ink));
      expect(item.buttons, palette);
      if (item.congruent) {
        congruent++;
      }
    }
    expect(congruent, inInclusiveRange(50, 150));
  });

  test('words 9+ never match their ink', () {
    for (var seed = 0; seed < 50; seed++) {
      final random = Random(seed);
      for (var number = 9; number < 50; number++) {
        final item = GuessColorEngine.generate(number, random);
        expect(item.congruent, isFalse);
        expect(item.buttons, hasLength(6));
        expect(item.buttons, contains(item.ink));
      }
    }
  });

  test('buttons follow the palette on words 9–18', () {
    final random = Random(7);
    for (var i = 0; i < 50; i++) {
      expect(
        GuessColorEngine.generate(9 + i % 10, random).buttons,
        InkColor.values,
      );
    }
  });

  test('buttons are reshuffled from word 19', () {
    final random = Random(7);
    var differs = 0;
    for (var i = 0; i < 50; i++) {
      final buttons = GuessColorEngine.generate(19 + i, random).buttons;
      expect(buttons.toSet(), InkColor.values.toSet());
      if (!listEquals(buttons, InkColor.values)) {
        differs++;
      }
    }
    expect(differs, greaterThan(0));
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
    expect(easy.item.buttons, hard.item.buttons);
    easy.dispose();
    hard.dispose();
  });

  test('correct pick scores and locks', () {
    final e = engine();
    e.pick(e.item.ink);
    expect(e.correct, 1);
    expect(e.score, 10);
    expect(e.picked, isNotNull);
    expect(e.locked, isTrue);
    e.dispose();
  });

  test('wrong pick counts a miss and locks', () {
    final e = engine();
    final color = wrongColor(e);
    e.pick(color);
    expect(e.wrong, 1);
    expect(e.score, 0);
    expect(e.picked, color);
    expect(e.locked, isTrue);
    e.dispose();
  });

  test('picks are ignored while locked or finished', () {
    final e = engine();
    e.pick(e.item.ink);
    e.pick(e.item.ink);
    expect(e.correct, 1);
    e.dispose();

    final done = engine()..finish();
    done.pick(done.item.ink);
    expect(done.correct, 0);
    expect(done.wrong, 0);
    done.dispose();
  });

  test('next word appears after the pause', () {
    fakeAsync((async) {
      final e = engine();
      e.pick(e.item.ink);
      async.elapse(const Duration(milliseconds: 200));
      expect(e.number, 1);
      expect(e.locked, isTrue);
      async.elapse(const Duration(milliseconds: 100));
      expect(e.number, 2);
      expect(e.picked, isNull);
      expect(e.locked, isFalse);
      e.pick(e.item.ink);
      expect(e.correct, 2);
      e.dispose();
    });
  });

  test('the round grows to 6 colors after word 8', () {
    fakeAsync((async) {
      final e = engine();
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

  test('finishing cancels the pending next word', () {
    fakeAsync((async) {
      final e = engine();
      e.pick(wrongColor(e));
      e.finish();
      async.elapse(const Duration(seconds: 1));
      expect(e.number, 1);
      expect(e.result?.wrong, 1);
      e.dispose();
    });
  });
}
