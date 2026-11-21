import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/games/angle_sense/degree_tape.dart';

void main() {
  const ppd = DegreeTape.pixelsPerDegree;

  /// Pumps a 320 px tape starting at [start]; returns every whole degree it
  /// reports, the last being the current value.
  Future<List<int>> pumpTape(
    WidgetTester tester, {
    int start = 90,
    bool calm = false,
  }) async {
    final values = <int>[start];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: LS.bg,
          body: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) => DegreeTape(
                  value: values.last.toDouble(),
                  onChanged: (v) => setState(() => values.add(v)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return values;
  }

  /// Drags [steps] moves of [dx] px, [every] apart, and leaves the finger
  /// down.
  Future<TestGesture> drag(
    WidgetTester tester, {
    required double dx,
    required int steps,
    required Duration every,
  }) async {
    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(find.byType(DegreeTape)));
    var at = Duration.zero;
    for (var i = 0; i < steps; i++) {
      at += every;
      await gesture.moveBy(Offset(dx, 0), timeStamp: at);
      await tester.pump(every);
    }
    return gesture;
  }

  test('the gain eases from 1 to the cap', () {
    expect(DegreeTape.gainFor(0), 1);
    expect(DegreeTape.gainFor(DegreeTape.slowSpeed), 1);
    final mid = DegreeTape.gainFor(
      (DegreeTape.slowSpeed + DegreeTape.fastSpeed) / 2,
    );
    expect(mid, closeTo(2, 1e-9));
    expect(DegreeTape.gainFor(DegreeTape.fastSpeed), DegreeTape.maxGain);
    expect(DegreeTape.gainFor(10000), DegreeTape.maxGain);
    // No jumps: small speed steps make small gain steps.
    for (var v = 0.0; v < 2000; v += 10) {
      expect(
        (DegreeTape.gainFor(v + 10) - DegreeTape.gainFor(v)).abs(),
        lessThan(0.03),
      );
    }
  });

  testWidgets('a slow drag of N px moves N / pixelsPerDegree degrees', (
    tester,
  ) async {
    final values = await pumpTape(tester);
    // 120 px/s, well under the gain threshold.
    final gesture = await drag(
      tester,
      dx: -6,
      steps: 20,
      every: const Duration(milliseconds: 50),
    );
    expect(values.last, 90 + 120 ~/ ppd);
    // Every whole degree on the way, none skipped.
    expect(values.toSet().length, values.length);
    expect(values, List.generate(21, (i) => 90 + i));
    await gesture.up(timeStamp: const Duration(milliseconds: 1050));
    await tester.pumpAndSettle();
    expect(values.last, 110);
  });

  testWidgets('a fast drag moves more, but at most 3× as far', (tester) async {
    final values = await pumpTape(tester, start: 60);
    // 3,000 px/s for 300 px: 50° at 1:1.
    final gesture = await drag(
      tester,
      dx: -30,
      steps: 10,
      every: const Duration(milliseconds: 10),
    );
    final moved = values.last - 60;
    expect(moved, greaterThan(300 ~/ ppd));
    expect(moved, lessThanOrEqualTo(3 * 300 ~/ ppd));
    await gesture.up(timeStamp: const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });

  testWidgets('a fling glides on, then settles on a whole degree', (
    tester,
  ) async {
    final values = await pumpTape(tester, start: 60);
    final gesture = await drag(
      tester,
      dx: -30,
      steps: 10,
      every: const Duration(milliseconds: 10),
    );
    final released = values.last;
    await gesture.up(timeStamp: const Duration(milliseconds: 100));
    await tester.pump(); // the fling's first frame
    await tester.pump(const Duration(milliseconds: 200));
    expect(values.last, greaterThan(released), reason: 'still gliding');
    await tester.pumpAndSettle();
    final landed = values.last;
    expect(landed - released, greaterThan(0));
    expect(landed - released, lessThanOrEqualTo(DegreeTape.maxFling + 1));
    // Settled: nothing more moves.
    final count = values.length;
    await tester.pump(const Duration(seconds: 1));
    expect(values.length, count);
  });

  testWidgets('a tap during a fling stops it', (tester) async {
    final values = await pumpTape(tester, start: 60);
    final gesture = await drag(
      tester,
      dx: -30,
      steps: 10,
      every: const Duration(milliseconds: 10),
    );
    final released = values.last;
    await gesture.up(timeStamp: const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final atTap = values.last;
    expect(atTap, greaterThan(released), reason: 'gliding when tapped');
    await tester.tap(find.byType(DegreeTape));
    await tester.pumpAndSettle();
    expect((values.last - atTap).abs(), lessThanOrEqualTo(1));
    // Well short of where the fling would have gone.
    expect(values.last - released, lessThan(DegreeTape.maxFling - 10));
  });

  testWidgets('a slow release just snaps, no fling', (tester) async {
    final values = await pumpTape(tester);
    final gesture = await drag(
      tester,
      dx: -5,
      steps: 10,
      every: const Duration(milliseconds: 50),
    );
    final released = values.last;
    await gesture.up(timeStamp: const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect((values.last - released).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('reduce motion: no fling, it snaps at once', (tester) async {
    final values = await pumpTape(tester, start: 60, calm: true);
    final gesture = await drag(
      tester,
      dx: -30,
      steps: 10,
      every: const Duration(milliseconds: 10),
    );
    final released = values.last;
    await gesture.up(timeStamp: const Duration(milliseconds: 100));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(values.last, released);
  });

  testWidgets('stays in 0–360', (tester) async {
    final values = await pumpTape(tester, start: 355);
    final gesture = await drag(
      tester,
      dx: -6,
      steps: 20,
      every: const Duration(milliseconds: 50),
    );
    expect(values.last, 360);
    await gesture.up(timeStamp: const Duration(milliseconds: 1050));
    await tester.pumpAndSettle();
    expect(values.last, 360);
  });
}
