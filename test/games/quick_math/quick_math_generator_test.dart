import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/quick_math/quick_math_controller.dart';

void main() {
  group('QuickMathQuestionFactory', () {
    test('creates four unique options including the correct answer', () {
      final question = QuickMathQuestionFactory.createForLevel(
        3,
        random: Random(4),
      );

      expect(question.options, hasLength(4));
      expect(question.options.toSet(), hasLength(4));
      expect(question.options, contains(question.correctAnswer));
    });

    test('hard division questions always produce whole number answers', () {
      final random = Random(6);

      for (var index = 0; index < 20; index++) {
        final question = QuickMathQuestionFactory.createForLevel(
          5,
          random: random,
        );

        if (!question.prompt.contains('÷')) {
          continue;
        }

        final parts = question.prompt.split(' ');
        final left = int.parse(parts[0]);
        final right = int.parse(parts[2]);
        final answer = int.parse(question.correctAnswer);

        expect(left % right, 0);
        expect(left ~/ right, answer);
      }
    });
  });
}
