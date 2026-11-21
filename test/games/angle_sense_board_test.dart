import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/games/angle_sense/angle_sense_board.dart';
import 'package:logic_sprint/games/angle_sense/angle_painter.dart';
import 'package:logic_sprint/games/angle_sense/angle_sense_engine.dart';
import 'package:logic_sprint/games/angle_sense/angle_shields.dart';
import 'package:logic_sprint/games/angle_sense/degree_tape.dart';
import 'package:logic_sprint/models/game.dart';

// Pumps the board on its own: the round host needs the whole app wired up.
void main() {
  const reveal = AngleSenseEngine.revealDuration;
  const slow = AngleSenseEngine.closeSweep;
  const perfect = AngleSenseEngine.perfectReveal;
  const frame = Duration(milliseconds: 16);

  AngleSenseEngine newEngine([Difficulty d = Difficulty.easy]) =>
      AngleSenseEngine(difficulty: d, random: Random(1));

  Future<void> pumpBoard(
    WidgetTester tester,
    AngleSenseEngine engine, {
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
            builder: (context, _) => AngleSenseBoard(engine: engine),
          ),
        ),
      ),
    );
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  final loupe = find.byKey(const ValueKey('angle-loupe'));

  final verdict = find.textContaining(
    RegExp(r'^(HIT|SHARP|PERFECT|SO CLOSE|MISS|TIME)'),
  );

  testWidgets('renders READ: card, tape, readout and buttons', (tester) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    expect(find.byType(DegreeTape), findsOneWidget);
    expect(find.bySemanticsLabel('Angle to read'), findsOneWidget);
    expect(find.text('LOCK'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.textContaining('EASY · Q01'), findsOneWidget);
    expect(find.text('WINDOW ±8°', findRichText: true), findsOneWidget);
    expect(textColor(tester, 'READ'), GameId.angleSense.accent);
    expect(textColor(tester, 'DRAW'), LS.dim);
    expect(verdict, findsNothing);
    final lock = find.ancestor(
      of: find.text('LOCK'),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(lock.first).height, greaterThanOrEqualTo(48));
    engine.finish();
  });

  testWidgets('the nudge buttons move the tape', (tester) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(engine.guess, 91);
    expect(find.text('91°', findRichText: true), findsOneWidget);
    await tester.drag(find.byType(DegreeTape), const Offset(-60, 0));
    await tester.pump();
    expect(engine.guess, greaterThan(91));
    engine.finish();
  });

  testWidgets('a normal hit gives a verdict after the 700 ms sweep', (
    tester,
  ) async {
    final engine = newEngine()..start();
    engine.setGuess(engine.question.answer - 5);
    await pumpBoard(tester, engine);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(engine.outcome!.tier, RevealTier.normal);
    expect(verdict, findsNothing); // still sweeping
    expect(loupe, findsNothing);
    await tester.pump(reveal + frame);
    expect(find.text('HIT −5°'), findsOneWidget);
    // The tape lands on the truth.
    expect(
      find.text('${engine.question.answer}°', findRichText: true),
      findsOneWidget,
    );
    await tester.pump(AngleSenseEngine.hitPause);
    expect(engine.number, 2);
    expect(verdict, findsNothing);
    engine.finish();
  });

  testWidgets('perfect shows the gold PERFECT chip, no loupe', (tester) async {
    final engine = newEngine()..start();
    engine.setGuess(engine.question.answer);
    await pumpBoard(tester, engine);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(engine.outcome!.tier, RevealTier.perfect);
    expect(verdict, findsNothing);
    await tester.pump(perfect + frame);
    expect(find.text('PERFECT 0°'), findsOneWidget);
    expect(textColor(tester, 'PERFECT 0°'), LS.gold);
    expect(loupe, findsNothing);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<AnglePainter>()
        .single;
    expect(painter.sweep, 1);
    engine.finish();
  });

  testWidgets('close: the loupe eases in, sweeps slowly, shows the gap', (
    tester,
  ) async {
    final engine = newEngine()..start();
    engine.setGuess(engine.question.answer + 2);
    await pumpBoard(tester, engine);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(engine.outcome!.tier, RevealTier.close);
    expect(loupe, findsOneWidget);
    expect(find.text('Δ 2°'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Zoomed in: off by 2 degrees'),
      findsOneWidget,
    );
    // Still in slow motion where the plain reveal would be done.
    await tester.pump(reveal + frame);
    expect(verdict, findsNothing);
    await tester.pump(slow - reveal);
    expect(find.text('SHARP +2°'), findsOneWidget);
    expect(textColor(tester, 'SHARP +2°'), sharpTint);
    expect(
      find.text('${engine.question.answer}°', findRichText: true),
      findsOneWidget,
    );
    // The loupe holds, then the next question clears it.
    await tester.pump(AngleSenseEngine.closeHold);
    expect(loupe, findsOneWidget);
    await tester.pump(AngleSenseEngine.hitPause);
    expect(engine.number, 2);
    expect(loupe, findsNothing);
    engine.finish();
  });

  testWidgets('a near miss gets the loupe and a coral SO CLOSE chip', (
    tester,
  ) async {
    final engine = newEngine()..start();
    engine.setGuess(engine.question.answer + 10);
    await pumpBoard(tester, engine);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(engine.outcome!.grade, AngleGrade.miss);
    expect(loupe, findsOneWidget);
    await tester.pump(slow + frame);
    expect(find.text('SO CLOSE +10°'), findsOneWidget);
    expect(textColor(tester, 'SO CLOSE +10°'), LS.coral);
    expect(textColor(tester, 'Δ 10°'), LS.coral);
    engine.finish();
  });

  testWidgets('reduce motion shows the loupe and verdict at once', (
    tester,
  ) async {
    final engine = newEngine()..start();
    engine.setGuess(engine.question.answer - 3);
    await pumpBoard(tester, engine, calm: true);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(loupe, findsOneWidget);
    expect(find.text('Δ 3°'), findsOneWidget);
    expect(find.text('SHARP −3°'), findsOneWidget);
    final fade = tester.widget<Opacity>(
      find.descendant(of: loupe, matching: find.byType(Opacity)).first,
    );
    expect(fade.opacity, 1);
    engine.finish();
  });

  testWidgets('reduce motion shows the verdict at once', (tester) async {
    final engine = newEngine()..start();
    engine.setGuess(engine.question.answer);
    await pumpBoard(tester, engine, calm: true);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(find.text('PERFECT 0°'), findsOneWidget);
    engine.finish();
  });

  ShieldPainter shieldPainter(WidgetTester tester, int i) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byKey(ValueKey('shield-$i')),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as ShieldPainter;

  testWidgets('2 shields; a miss breaks one as its verdict shows', (
    tester,
  ) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    expect(find.bySemanticsLabel('Shields: 2 of 2'), findsOneWidget);
    expect(shieldPainter(tester, 1).full, isTrue);
    final truth = engine.question.answer;
    engine.setGuess(truth >= 180 ? truth - 90 : truth + 90);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    // Held up until the verdict.
    expect(find.bySemanticsLabel('Shields: 2 of 2'), findsOneWidget);
    await tester.pump(reveal + frame);
    expect(verdict, findsOneWidget);
    expect(tester.widget<Text>(verdict).style?.color, LS.coral);
    expect(find.bySemanticsLabel('Shields: 1 of 2'), findsOneWidget);
    await tester.pump(frame);
    final breaking = shieldPainter(tester, 1);
    expect(breaking.full, isFalse);
    expect(breaking.breaking, lessThan(1));
    expect(shieldPainter(tester, 0).full, isTrue);
    // The break plays out.
    await tester.pump(AngleShield.breakDuration + frame);
    expect(shieldPainter(tester, 1).breaking, 1);
    engine.finish();
  });

  testWidgets('reduce motion: a lost shield goes straight to the outline', (
    tester,
  ) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine, calm: true);
    final truth = engine.question.answer;
    engine.setGuess(truth >= 180 ? truth - 90 : truth + 90);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    expect(find.bySemanticsLabel('Shields: 1 of 2'), findsOneWidget);
    await tester.pump();
    expect(shieldPainter(tester, 1).full, isFalse);
    expect(shieldPainter(tester, 1).breaking, 1);
    engine.finish();
  });

  testWidgets('a revive gives back one shield after the countdown', (
    tester,
  ) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine, calm: true);
    for (var i = 0; i < AngleSenseEngine.maxStrikes; i++) {
      final truth = engine.question.answer;
      engine.setGuess(truth >= 180 ? truth - 90 : truth + 90);
      engine.lock();
      await tester.pump(AngleSenseEngine.revealDuration);
      await tester.pump(AngleSenseEngine.missPause);
    }
    expect(engine.state.name, 'down');
    expect(find.bySemanticsLabel('Shields: 0 of 2'), findsOneWidget);
    engine.revive(hold: true);
    await tester.pump();
    expect(find.bySemanticsLabel('Shields: 1 of 2'), findsOneWidget);
    // Waits for the get-ready countdown, then pops in.
    expect(shieldPainter(tester, 0).full, isFalse);
    engine.go();
    await tester.pump();
    await tester.pump(AngleShield.popDuration + frame);
    expect(shieldPainter(tester, 0).full, isTrue);
    expect(shieldPainter(tester, 1).full, isFalse);
    engine.finish();
  });

  testWidgets('long-pressing +1 repeats, faster after a moment', (
    tester,
  ) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('+1')),
    );
    await tester.pump(kLongPressTimeout + frame);
    expect(engine.guess, 91);
    // 8/s for 600 ms, then 20/s.
    await tester.pump(const Duration(milliseconds: 500));
    final early = engine.guess;
    expect(early - 91, inInclusiveRange(3, 5));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(engine.guess - early, greaterThanOrEqualTo(15));
    await gesture.up();
    final held = engine.guess;
    await tester.pump(const Duration(milliseconds: 500));
    expect(engine.guess, held);
    engine.finish();
  });

  testWidgets('the switch lights DRAW on a DRAW question', (tester) async {
    final engine = newEngine(Difficulty.hard)..start();
    engine.question = AngleSenseEngine.generate(
      20,
      Difficulty.hard,
      Random(1),
      previousRule: AngleRule.draw,
      ruleRun: 1,
    );
    expect(engine.rule, AngleRule.draw);
    await pumpBoard(tester, engine);
    await tester.pump(const Duration(milliseconds: 500));
    expect(textColor(tester, 'DRAW'), GameId.angleSense.accent);
    expect(textColor(tester, 'READ'), LS.dim);
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
      Alignment.centerRight,
    );
    // The target is shown, there's no tape, and Lock waits for an aim.
    expect(find.text('${engine.question.answer}°'), findsOneWidget);
    expect(find.byType(DegreeTape), findsNothing);
    await tester.tap(find.text('LOCK'));
    expect(engine.outcome, isNull);
    engine.finish();
  });

  testWidgets('DRAW: dragging on the card aims the arm', (tester) async {
    final engine = newEngine(Difficulty.hard)..start();
    engine.question = const AngleQuestion(
      kind: AngleKind.drawRotated,
      answer: 90,
      vertex: Offset(0.5, 0.5),
      base: 0,
    );
    await pumpBoard(tester, engine);
    final card = find.bySemanticsLabel(RegExp('Drag the second arm'));
    final rect = tester.getRect(card);
    // Straight up from the vertex (the card's centre) is 90°.
    await tester.tapAt(rect.center - Offset(0, rect.height * 0.3));
    await tester.pump();
    expect(engine.drawGuess, 90);
    await tester.tap(find.text('LOCK'));
    await tester.pump();
    await tester.pump(perfect + frame);
    expect(find.text('PERFECT 0°'), findsOneWidget);
    engine.finish();
  });

  testWidgets('a Medium compass round shows the heading', (tester) async {
    final engine = newEngine(Difficulty.medium)
      ..number = 10
      ..question = AngleSenseEngine.generate(10, Difficulty.medium, Random(2))
      ..start();
    await pumpBoard(tester, engine);
    expect(find.textContaining('COMPASS ROUND'), findsOneWidget);
    expect(find.text('WINDOW ±12°', findRichText: true), findsOneWidget);
    expect(find.text(engine.question.heading), findsOneWidget);
    engine.finish();
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    expect(tester.takeException(), isNull);
    final card = tester.getSize(find.bySemanticsLabel('Angle to read'));
    expect(card.width, greaterThan(150));
    engine.finish();
  });
}
