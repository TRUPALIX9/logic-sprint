import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/theme.dart';
import 'package:logic_sprint/games/rocket_launch/rocket_look.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// Degrees between two hues, 0..180.
double _hueGap(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return min(d, 360 - d);
}

void main() {
  for (final (i, theme) in SpaceTheme.all.indexed) {
    test('theme $i: rocks and ship stand out from space', () {
      // The rock body is its tint shaded 20% toward black (see the painter).
      final body = Color.lerp(theme.rock, LS.bg, 0.2)!;
      expect(_contrast(body, theme.space), greaterThan(3), reason: 'rock');
      expect(
        _contrast(theme.hull, theme.space),
        greaterThan(7),
        reason: 'ship',
      );
      // Space itself is near black (its hue barely shows; contrast covers
      // it), so the hue check is against the coloured nebula glows.
      for (final glow in theme.glows) {
        expect(
          _hueGap(theme.rock, glow),
          greaterThan(45),
          reason: 'rock hue vs background $glow',
        );
      }
    });
  }
}
