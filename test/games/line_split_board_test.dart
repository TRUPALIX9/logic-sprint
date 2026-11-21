import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/games/line_split/line_split_board.dart';
import 'package:logic_sprint/games/line_split/line_split_engine.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/ui/kit.dart';

// Pumps the board on its own: the round host needs the whole app wired up.
void main() {
  LineSplitEngine newEngine({SplitQuestion? question}) {
    final engine = LineSplitEngine(
      difficulty: Difficulty.medium,
      random: Random(1),
    );
    if (question != null) {
      engine.question = question;
    }
    return engine;
  }

  Future<void> pumpBoard(
    WidgetTester tester,
    LineSplitEngine engine, {
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
            builder: (context, _) => LineSplitBoard(engine: engine),
          ),
        ),
      ),
    );
    // Let the reveal finish easing in, so the card has its final transform.
    await tester.pump(const Duration(milliseconds: 300));
  }

  final lineCanvas = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is LinePainter,
  );

  /// The global position of share [u] along the current line.
  Offset pointOn(WidgetTester tester, LineSplitEngine engine, double u) {
    final rect = tester.getRect(lineCanvas);
    final frame = (Offset.zero & rect.size).deflate(34);
    return rect.topLeft + engine.question.line.at(frame, u);
  }

  List<bool> shields(WidgetTester tester) => [
    for (var i = 0; i < LineSplitEngine.maxStrikes; i++)
      tester.widget<Shield>(find.byKey(ValueKey('shield-$i'))).full,
  ];

  /// One frame past [duration]: an AnimationController completes on the
  /// first frame after it.
  Duration past(Duration duration) =>
      duration + const Duration(milliseconds: 16);

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

  LinePainter linePainter(WidgetTester tester) =>
      tester.widget<CustomPaint>(lineCanvas).painter! as LinePainter;

  testWidgets('shows a stacked fraction target and the line', (tester) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);

    final fraction = find.byType(StackedFraction);
    expect(fraction, findsOneWidget);
    expect(
      find.descendant(of: fraction, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fraction, matching: find.text('2')),
      findsOneWidget,
    );
    expect(find.text('1/2'), findsNothing);
    expect(find.text('FROM THE 0 END'), findsOneWidget);
    expect(lineCanvas, findsOneWidget);
    expect(find.textContaining('Q01'), findsOneWidget);
    expect(find.text('±5%'), findsOneWidget);
    engine.finish();
  });

  testWidgets('decimal and "from the 1 end" targets', (tester) async {
    final engine = newEngine(
      question: const SplitQuestion(
        target: SplitTarget.decimal(0.30, fromOne: true),
        line: SplitLine(degrees: 30, length: 0.8),
      ),
    )..start();
    await pumpBoard(tester, engine);
    expect(find.text('0.30'), findsOneWidget);
    expect(find.text('FROM THE 1 END'), findsOneWidget);
    expect(find.byType(StackedFraction), findsNothing);
    engine.finish();
  });

  testWidgets('press, slide and lift answers where the finger is', (
    tester,
  ) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);

    final gesture = await tester.startGesture(pointOn(tester, engine, 0.2));
    await tester.pump();
    expect(engine.aim.value, closeTo(0.2, 0.01));
    expect(engine.outcome, isNull);

    // Slide along the line, drifting off it: the marker follows, projected.
    await gesture.moveTo(pointOn(tester, engine, 0.35) + const Offset(0, 25));
    await tester.pump();
    expect(engine.aim.value, closeTo(0.35, 0.01));
    await gesture.moveTo(pointOn(tester, engine, 0.5) + const Offset(0, -20));
    await tester.pump();
    expect(engine.outcome, isNull, reason: 'nothing counts until the lift');

    await gesture.up();
    await tester.pump();
    expect(engine.outcome!.verdict, SplitVerdict.bullseye);
    expect(engine.score, 20);
    expect(find.text('PERFECT +0.0%'), findsOneWidget);
    expect(find.byType(VerdictChip), findsOneWidget);

    await tester.pump(LineSplitEngine.perfectPause);
    expect(engine.number, 2);
    expect(find.byType(VerdictChip), findsNothing);
    engine.finish();
  });

  testWidgets('a miss breaks a shield', (tester) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    expect(shields(tester), [true, true]);
    expect(find.bySemanticsLabel('Shields: 2 of 2'), findsOneWidget);

    final gesture = await tester.startGesture(pointOn(tester, engine, 0.9));
    await gesture.up();
    await tester.pump();
    expect(engine.outcome!.verdict, SplitVerdict.miss);
    expect(find.text('MISS +40.0%'), findsOneWidget);
    expect(shields(tester), [true, false]);
    expect(find.bySemanticsLabel('Shields: 1 of 2'), findsOneWidget);

    // The break plays out, then the shield is a dim outline.
    await tester.pump(const Duration(milliseconds: 100));
    expect(shieldPainter(tester, 1).breaking, inExclusiveRange(0, 1));
    await tester.pump(past(Shield.breakTime));
    expect(shieldPainter(tester, 1).breaking, 1);

    await tester.pump(LineSplitEngine.missPause);
    expect(engine.number, 2);
    expect(engine.isPlaying, isTrue);
    engine.finish();
  });

  testWidgets('accessible slider adjusts by 1% and answers', (tester) async {
    final semantics = tester.ensureSemantics();
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);

    final slider = find.bySemanticsLabel(RegExp('Your mark'));
    expect(slider, findsOneWidget);
    final node = tester.getSemantics(slider);
    expect(node.label, contains('Target 1/2 from the 0 end'));
    expect(node.label, contains('0 at the left, 1 at the right'));
    expect(node.value, '50%');

    final owner = node.owner!;
    owner.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(engine.aim.value, closeTo(0.51, 1e-9));
    expect(tester.getSemantics(slider).value, '51%');

    final answer = tester
        .getSemantics(slider)
        .getSemanticsData()
        .customSemanticsActionIds!
        .single;
    owner.performAction(node.id, SemanticsAction.customAction, answer);
    await tester.pump();
    expect(engine.outcome!.verdict, SplitVerdict.bullseye);
    expect(engine.outcome!.answer, closeTo(0.51, 1e-9));
    engine.finish();
    semantics.dispose();
  });

  testWidgets('the target is hidden while counting back in', (tester) async {
    final engine = newEngine()..start();
    await pumpBoard(tester, engine);
    for (var i = 0; i < LineSplitEngine.maxStrikes; i++) {
      engine.answer(engine.question.target.position + 0.45);
      await tester.pump(LineSplitEngine.missPause);
    }
    expect(engine.isPlaying, isFalse);
    expect(shields(tester), [false, false]);
    engine.revive(hold: true);
    await tester.pump(const Duration(milliseconds: 400));
    final hidden = tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(TargetLabel),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .first;
    expect(hidden.opacity, 0);
    // The restored shield waits for the countdown, then pops in.
    expect(shields(tester), [false, false]);
    engine.go();
    await tester.pump();
    expect(shields(tester), [true, false]);
    expect(find.bySemanticsLabel('Shields: 1 of 2'), findsOneWidget);
    final pop = find.descendant(
      of: find.byKey(const ValueKey('shield-0')),
      matching: find.byType(Transform),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<Transform>(pop).transform.storage[0], lessThan(1));
    await tester.pump(past(Shield.popTime));
    expect(
      tester.widget<Transform>(pop).transform.storage[0],
      closeTo(1, 1e-9),
    );
    engine.finish();
  });

  testWidgets('later stages paint decoys, ticks and a countdown', (
    tester,
  ) async {
    for (final number in [13, 41, 51]) {
      final engine = newEngine()
        ..number = number
        ..question = LineSplitEngine.generate(number, Random(number))
        ..start();
      await pumpBoard(tester, engine);
      expect(tester.takeException(), isNull);
      if (engine.timeLimit != null) {
        expect(find.byType(FractionallySizedBox), findsOneWidget);
        await tester.pump(engine.timeLimit! + const Duration(milliseconds: 16));
        expect(engine.timedOut, isTrue);
        expect(find.text('TIME'), findsOneWidget);
      }
      engine.finish();
    }
  });

  group('reveal tiers', () {
    testWidgets('perfect: a gold chip and the golden line', (tester) async {
      final engine = newEngine()..start();
      await pumpBoard(tester, engine);
      engine.answer(engine.question.target.position + 0.004);
      await tester.pump();
      expect(find.text('PERFECT +0.4%'), findsOneWidget);
      final chip = tester.widget<DisplayText>(
        find.descendant(
          of: find.byType(VerdictChip),
          matching: find.byType(DisplayText),
        ),
      );
      expect(chip.color, LS.gold);
      expect(find.byType(RevealLoupe), findsNothing);
      await tester.pump(past(LineSplitEngine.perfectPause) ~/ 2);
      expect(linePainter(tester).reveal.value, inExclusiveRange(0, 1));
      expect(tester.takeException(), isNull);
      engine.finish();
    });

    testWidgets('sharp: the loupe opens and the gap slides in slowly', (
      tester,
    ) async {
      final engine = newEngine()..start();
      await pumpBoard(tester, engine);
      engine.answer(engine.question.target.position + 0.016);
      await tester.pump();
      expect(find.text('SHARP +1.6%'), findsOneWidget);
      expect(find.byType(RevealLoupe), findsOneWidget);
      expect(find.text('Δ 0.0%'), findsOneWidget);
      final opacity = find.descendant(
        of: find.byType(RevealLoupe),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, 0);

      await tester.pump(past(LoupeLayout.easeIn));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(find.text('Δ 1.6%'), findsNothing, reason: 'still sliding');

      await tester.pump(past(LineSplitEngine.closeSlide));
      expect(find.text('Δ 1.6%'), findsOneWidget);
      // The loupe sits clear of the line.
      final card = tester.getRect(lineCanvas);
      final loupe = tester.getRect(find.byType(RevealLoupe));
      final lineY = pointOn(tester, engine, 0.5).dy;
      expect(lineY < loupe.top || lineY > loupe.bottom, isTrue);
      expect(card.contains(loupe.center), isTrue);

      // Held, then the next question.
      await tester.pump(LineSplitEngine.closeHold);
      expect(engine.number, 2);
      expect(find.byType(RevealLoupe), findsNothing);
      engine.finish();
    });

    testWidgets('a near miss is coral "SO CLOSE" with the loupe', (
      tester,
    ) async {
      final engine = newEngine()..start();
      await pumpBoard(tester, engine);
      engine.answer(engine.question.target.position + 0.07);
      await tester.pump();
      expect(find.text('SO CLOSE +7.0%'), findsOneWidget);
      expect(find.byType(RevealLoupe), findsOneWidget);
      await tester.pump(past(LineSplitEngine.closeSlide));
      final delta = tester.widget<Text>(find.text('Δ 7.0%'));
      expect(delta.style!.color, LS.coral);
      engine.finish();
    });

    testWidgets('a far miss keeps the plain reveal', (tester) async {
      final engine = newEngine()..start();
      await pumpBoard(tester, engine);
      engine.answer(engine.question.target.position + 0.2);
      await tester.pump();
      expect(find.text('MISS +20.0%'), findsOneWidget);
      expect(find.byType(RevealLoupe), findsNothing);
      engine.finish();
    });

    testWidgets('reduce motion: the loupe and gold line show at once', (
      tester,
    ) async {
      final engine = newEngine()..start();
      await pumpBoard(tester, engine, calm: true);
      engine.answer(engine.question.target.position + 0.016);
      await tester.pump();
      expect(find.byType(RevealLoupe), findsOneWidget);
      expect(find.text('Δ 1.6%'), findsOneWidget);
      final opacity = find.descendant(
        of: find.byType(RevealLoupe),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      // The engine's timing doesn't change.
      await tester.pump(LineSplitEngine.closePause);
      expect(engine.number, 2);

      engine.answer(engine.question.target.position + 0.0);
      await tester.pump();
      expect(find.text('PERFECT +0.0%'), findsOneWidget);
      expect(linePainter(tester).reveal.value, 1);

      // A lost shield just switches to the outline.
      await tester.pump(LineSplitEngine.perfectPause);
      engine.answer(engine.question.target.position + 0.45);
      await tester.pump();
      expect(shieldPainter(tester, 1).breaking, 1);
      engine.finish();
    });
  });

  group('longer number lines', () {
    testWidgets('a mixed number: a big whole beside a small fraction', (
      tester,
    ) async {
      final engine = newEngine(
        question: const SplitQuestion(
          target: SplitTarget.mixed(1, 1, 2, units: 2),
          line: SplitLine(degrees: 0, length: 0.9),
        ),
      )..start();
      await pumpBoard(tester, engine);
      final fraction = find.byType(StackedFraction);
      expect(tester.widget<StackedFraction>(fraction).size, 20);
      expect(find.text('ON 0 TO 2'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Target 1 1/2 on a line from 0 to 2'),
        findsOneWidget,
      );
      // The subtitle sits under the value, centred with it.
      final value = tester.getRect(
        find.ancestor(of: fraction, matching: find.byType(Row)).first,
      );
      final subtitle = tester.getRect(find.text('ON 0 TO 2'));
      expect(subtitle.top, greaterThan(value.bottom - 1));
      expect(subtitle.center.dx, closeTo(value.center.dx, 1));

      // 1½ on 0–2 is three quarters of the line; the zoom works here too.
      engine.answer(0.75 + 0.015);
      await tester.pump();
      await tester.pump(past(LineSplitEngine.closeSlide));
      expect(find.text('Δ 1.5%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      engine.finish();
    });

    testWidgets('an improper fraction is stacked: 11 over 8', (tester) async {
      final engine = newEngine(
        question: const SplitQuestion(
          target: SplitTarget.fraction(11, 8, units: 2, unitTicks: false),
          line: SplitLine(degrees: 30, length: 0.9),
        ),
      )..start();
      await pumpBoard(tester, engine);
      final fraction = find.byType(StackedFraction);
      expect(tester.widget<StackedFraction>(fraction).size, 32);
      final top = tester.getRect(
        find.descendant(of: fraction, matching: find.text('11')),
      );
      final bottom = tester.getRect(
        find.descendant(of: fraction, matching: find.text('8')),
      );
      expect(top.bottom, lessThan(bottom.top));
      // Answering at the true point is perfect: the golden reveal.
      engine.answer(0.6875);
      await tester.pump();
      expect(find.text('PERFECT +0.0%'), findsOneWidget);
      await tester.pump(past(LineSplitEngine.perfectPause) ~/ 2);
      expect(linePainter(tester).reveal.value, inExclusiveRange(0, 1));
      await tester.pump(past(LineSplitEngine.perfectPause) ~/ 2);
      expect(tester.takeException(), isNull);
      engine.finish();
    });

    testWidgets('the semantics describe the span', (tester) async {
      final semantics = tester.ensureSemantics();
      final engine = newEngine(
        question: const SplitQuestion(
          target: SplitTarget.decimal(2.25, units: 3, unitTicks: false),
          line: SplitLine(degrees: 90, length: 0.9),
        ),
      )..start();
      await pumpBoard(tester, engine);
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Your mark')),
      );
      expect(node.label, contains('0 at the bottom, 3 at the top'));
      expect(node.label, contains('only its ends labelled'));
      // Beside an upright line the loupe still fits and shows.
      engine.answer(0.75 + 0.012);
      await tester.pump();
      await tester.pump(past(LineSplitEngine.closeSlide));
      expect(find.byType(RevealLoupe), findsOneWidget);
      expect(tester.takeException(), isNull);
      engine.finish();
      semantics.dispose();
    });
  });
}
