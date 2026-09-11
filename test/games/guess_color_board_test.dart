import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/games/guess_color/guess_color_board.dart';
import 'package:logic_sprint/games/guess_color/guess_color_engine.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/ui/chamfer.dart';

// Pumps the board on its own: the round host needs the whole app wired up.
void main() {
  final accent = GameId.guessColor.accent;

  GuessColorEngine newEngine() =>
      GuessColorEngine(difficulty: Difficulty.medium, random: Random(1));

  /// The first item for word [number] (across seeds) that passes [test].
  GuessItem itemWhere(int number, bool Function(GuessItem item) test) {
    for (var seed = 0; ; seed++) {
      final item = GuessColorEngine.generate(number, Random(seed));
      if (test(item)) {
        return item;
      }
    }
  }

  Future<void> pumpBoard(
    WidgetTester tester,
    GuessColorEngine engine, {
    bool calm = false,
  }) async {
    addTearDown(engine.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: LS.bg,
          body: AnimatedBuilder(
            animation: engine,
            builder: (context, _) => GuessColorBoard(engine: engine),
          ),
        ),
      ),
    );
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  Alignment litSide(WidgetTester tester) =>
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment
          as Alignment;

  Finder buttonFilled(InkColor fill) => find.byWidgetPredicate(
    (widget) => widget is ChamferBox && widget.color == fill.color,
  );

  testWidgets('switch lights COLOR on a COLOR turn', (tester) async {
    await pumpBoard(tester, newEngine());
    expect(textColor(tester, 'COLOR'), accent);
    expect(textColor(tester, 'TEXT'), LS.dim);
    expect(litSide(tester), Alignment.centerLeft);
    expect(
      find.textContaining(RegExp(r'\b(ink|word)\b', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('switch lights TEXT on a TEXT turn', (tester) async {
    final engine = newEngine()
      ..item = itemWhere(25, (item) => item.rule == GuessRule.text);
    await pumpBoard(tester, engine);
    await tester.pump(const Duration(milliseconds: 500));
    expect(textColor(tester, 'TEXT'), accent);
    expect(textColor(tester, 'COLOR'), LS.dim);
    expect(litSide(tester), Alignment.centerRight);
  });

  testWidgets('buttons show every fill with its label', (tester) async {
    final engine = newEngine()..item = itemWhere(35, (_) => true);
    await pumpBoard(tester, engine);
    for (final button in engine.item.buttons) {
      final slot = buttonFilled(button.fill);
      expect(slot, findsOneWidget);
      expect(
        find.descendant(
          of: slot,
          matching: find.text(button.label.label.toUpperCase()),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(slot).shortestSide, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('tapping a button picks its fill', (tester) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    await tester.tap(buttonFilled(engine.item.target));
    expect(engine.correct, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.number, 2);
  });

  testWidgets('the countdown shows no time readout', (tester) async {
    final engine = newEngine()
      ..number = 20
      ..start();
    await pumpBoard(tester, engine);
    await tester.pump(const Duration(milliseconds: 500));
    expect(engine.timeLimit, isNotNull);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
    engine.finish();
  });

  testWidgets('pulse and shake animate when motion is allowed', (tester) async {
    final engine = newEngine()
      ..item = itemWhere(45, (item) => item.pulse && item.shake)
      ..start();
    await pumpBoard(tester, engine);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduce motion stops pulse and shake', (tester) async {
    final engine = newEngine()
      ..item = itemWhere(45, (item) => item.pulse && item.shake)
      ..start();
    await pumpBoard(tester, engine, calm: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('labels stay readable on every fill', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
    }

    for (final fill in InkColor.values) {
      final colors = labelColorsOn(fill);
      final chip = colors.chip;
      final ground = chip == null
          ? fill.color
          : Color.alphaBlend(chip, fill.color);
      expect(
        contrast(colors.text, ground),
        greaterThanOrEqualTo(4.5),
        reason: fill.name,
      );
    }
  });
}
