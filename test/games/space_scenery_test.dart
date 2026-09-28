import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/rocket_launch/space_scenery.dart';

void main() {
  const size = Size(390, 700);

  /// Every star in the first [seconds] of flight, one per stream pass.
  List<({double angle, double? hitAt})> stars(int seconds) => {
    for (var stream = 0; stream < SceneryPainter.streams; stream++)
      for (var t = 0.0; t < seconds; t += 0.5)
        SceneryPainter.shootingStar(size, t, stream),
  }.map((s) => (angle: s.angle, hitAt: s.hitAt)).toList();

  test('shooting stars fly in every direction', () {
    final quadrants = {
      for (final s in stars(300)) (s.angle ~/ (pi / 2)).clamp(0, 3),
    };
    expect(quadrants, {0, 1, 2, 3});
  });

  test('some hit a planet (a small burst), most fly past', () {
    final all = stars(600);
    final hits = all.where((s) => s.hitAt != null).length;
    expect(all.length, greaterThan(200));
    expect(hits, greaterThan(0), reason: 'a burst now and then');
    expect(hits / all.length, lessThan(0.4), reason: 'but rarely');
  });

  test('the sky is the same every time', () {
    expect(
      SceneryPainter.shootingStar(size, 42.3, 1),
      SceneryPainter.shootingStar(size, 42.3, 1),
    );
  });
}
