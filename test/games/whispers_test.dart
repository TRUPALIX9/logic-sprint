import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/games/rocket_launch/whispers.dart';

void main() {
  test('lines are unique and short enough for one line', () {
    expect(whispers.toSet(), hasLength(whispers.length));
    for (final line in whispers) {
      expect(line.length, lessThanOrEqualTo(34), reason: line);
    }
  });

  test('no line repeats until every line has been shown', () {
    final random = Random(7);
    var seen = <String>[];
    final shown = <String>[];
    for (var i = 0; i < whispers.length; i++) {
      final (line, next) = nextWhisper(seen, random);
      shown.add(line);
      seen = next;
    }
    expect(shown.toSet(), whispers.toSet(), reason: 'all, once each');

    final (again, reset) = nextWhisper(seen, random);
    expect(whispers, contains(again));
    expect(reset, [again], reason: 'the pool starts over');
  });

  test('the order is random', () {
    String first(int seed) => nextWhisper(const [], Random(seed)).$1;
    expect({for (var s = 0; s < 20; s++) first(s)}.length, greaterThan(5));
  });
}
