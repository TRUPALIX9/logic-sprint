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
  group('PatternLockConfig', () {
    test('easy has 3 lives and starting length 3', () {
      final config = patternLockConfigFor(DifficultyLevel.easy);
      expect(config.lives, 3);
      expect(config.startingLength, 3);
      expect(config.maxLength, 6);
    });

    test('hard has 1 life', () {
      final config = patternLockConfigFor(DifficultyLevel.hard);
      expect(config.lives, 1);
      expect(config.startingLength, 5);
    });
  });

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
