import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';

void main() {
  test('every game has a short tip for the Game Over card', () {
    for (final game in GameId.values) {
      expect(game.tip.length, lessThan(60), reason: game.name);
    }
  });
}
