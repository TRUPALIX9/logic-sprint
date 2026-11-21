import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/models/sprint_level.dart';
import 'package:logic_sprint/ui/sprint_gauge.dart';

Future<void> _pumpGauge(
  WidgetTester tester,
  int? top, {
  bool reduceMotion = false,
  double width = 320,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: LayoutBuilder(
                builder: (context, c) => Center(
                  child: SprintGauge(
                    top: top,
                    diameter: c.maxWidth.clamp(0, 220).toDouble(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    // The sweep is 700 ms; an AnimationController completes on the first
    // frame after its duration. (No pumpAndSettle: gold keeps shimmering.)
    await tester.pump(SprintGauge.sweep);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

SprintGaugePainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(SprintGauge),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as SprintGaugePainter;

Color? _labelColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

/// Stops a shimmering gauge so the test ends with no ticker running.
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  group('SprintLevel', () {
    test('shown in every band; hidden only with no score', () {
      expect(const SprintLevel(20).ranked, isTrue);
      expect(const SprintLevel(40).label, 'Top 40%');
      expect(const SprintLevel(40).band, SprintBand.top50);
      expect(const SprintLevel(90).label, 'Top 90%');
      expect(const SprintLevel(90).band, SprintBand.top100);
      expect(const SprintLevel(null).ranked, isFalse);
      expect(const SprintLevel(null).label, isNull);
      expect(const SprintLevel(null).position, 0);
      expect(const SprintLevel(7).label, 'Top 7%');
    });

    test('bands and positions run dim to bright', () {
      expect(const SprintLevel(3).band, SprintBand.top5);
      expect(const SprintLevel(5).band, SprintBand.top5);
      expect(const SprintLevel(8).band, SprintBand.top10);
      expect(const SprintLevel(20).band, SprintBand.top25);
      final positions = [
        20,
        15,
        10,
        8,
        5,
        3,
        1,
      ].map((t) => SprintLevel(t).position).toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
      expect(positions.last, lessThanOrEqualTo(1));
    });
  });

  group('SprintGauge', () {
    testWidgets('a top-7% player sees TOP 7% in teal, read as a sentence', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpGauge(tester, 7);
      expect(find.text('TOP 7%'), findsOneWidget);
      expect(_labelColor(tester, 'TOP 7%'), LS.teal);
      expect(find.bySemanticsLabel('Top 7 percent of players'), findsOneWidget);
      final painter = _painter(tester);
      expect(painter.progress, 1);
      expect(painter.litBands, [
        SprintBand.top100,
        SprintBand.top50,
        SprintBand.top25,
        SprintBand.top10,
      ]);
      expect(
        find.textContaining(RegExp('sprint score', caseSensitive: false)),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('band colours: 3% gold, 8% teal, 20% blue', (tester) async {
      for (final (top, color, band) in [
        (3, LS.gold, SprintBand.top5),
        (8, LS.teal, SprintBand.top10),
        (20, LS.blue, SprintBand.top25),
      ]) {
        await _pumpGauge(tester, top);
        expect(find.text('TOP $top%'), findsOneWidget);
        expect(_labelColor(tester, 'TOP $top%'), color, reason: 'top $top%');
        expect(_painter(tester).litBands.last, band);
        await _unmount(tester);
      }
    });

    testWidgets('a top-1% player lights the gold band and it glows', (
      tester,
    ) async {
      await _pumpGauge(tester, 1);
      expect(_painter(tester).litBands, contains(SprintBand.top5));
      final style = tester.widget<Text>(find.text('TOP 1%')).style!;
      expect(style.color, LS.gold);
      expect(style.shadows, isNotEmpty);
      await _unmount(tester);
    });

    testWidgets('no score yet: dim, no fill, no percentage', (tester) async {
      for (final top in <int?>[null]) {
        await _pumpGauge(tester, top);
        expect(find.text('PLAY MORE GAMES TO GET YOUR SCORE'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing, reason: 'top $top');
        final painter = _painter(tester);
        expect(painter.litBands, isEmpty);
        expect(painter.fillEnd, 0);
        expect(painter.shimmer, isNull);
      }
    });

    testWidgets('sweeps in over 700 ms, then gold shimmers', (tester) async {
      await _pumpGauge(tester, 3, settle: false);
      expect(_painter(tester).progress, 0);
      await tester.pump(const Duration(milliseconds: 350));
      final half = _painter(tester).progress;
      expect(half, greaterThan(0));
      expect(half, lessThan(1));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_painter(tester).progress, 1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_painter(tester).shimmer, isNotNull);
      await _unmount(tester);
    });

    testWidgets('reduce motion: final state at once and no shimmer', (
      tester,
    ) async {
      await _pumpGauge(tester, 3, reduceMotion: true, settle: false);
      final painter = _painter(tester);
      expect(painter.progress, 1);
      expect(painter.shimmer, isNull);
      expect(find.text('TOP 3%'), findsOneWidget);
      // Nothing keeps ticking.
      await tester.pumpAndSettle();
      expect(_painter(tester).shimmer, isNull);
    });

    testWidgets('fits at 320 and on a narrow card without overflow', (
      tester,
    ) async {
      for (final width in [320.0, 150.0]) {
        for (final top in [1, 20, 21]) {
          await _pumpGauge(tester, top, width: width, reduceMotion: true);
          expect(tester.takeException(), isNull, reason: '$width / $top');
        }
      }
    });
  });
}
