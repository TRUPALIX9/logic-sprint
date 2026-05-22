import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/game/score_calculator.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/pattern_lock/pattern_lock_models.dart';

bool patternsMatch(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

void main() {
  group('Pattern matching', () {
    test('patterns must match order and length', () {
      expect(patternsMatch([0, 1, 4], [0, 1, 4]), isTrue);
      expect(patternsMatch([0, 1, 4], [0, 4, 1]), isFalse);
      expect(patternsMatch([0, 1], [0, 1, 4]), isFalse);
    });
  });

  group('Pattern Lock scoring', () {
    test('correct pattern scoring uses streak bonus', () {
      var score = 0;
      for (var streak = 1; streak <= 5; streak++) {
        score = ScoreCalculator.applyCorrect(
          currentScore: score,
          streakAfterCorrect: streak,
        );
      }
      expect(score, 70);
    });
  });
}
