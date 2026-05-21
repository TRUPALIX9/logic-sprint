import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/true_false/true_false_controller.dart';

void main() {
  group('TrueFalseQuestionFactory', () {
    test('always creates True and False options', () {
      final question = TrueFalseQuestionFactory.create(
        DifficultyLevel.medium,
        random: Random(11),
      );

      expect(question.options, const ['True', 'False']);
      expect(['True', 'False'], contains(question.correctAnswer));
    });

    test('prompt is not empty', () {
      final question = TrueFalseQuestionFactory.create(
        DifficultyLevel.hard,
        random: Random(3),
      );

      expect(question.prompt, isNotEmpty);
    });

    test('divisibility statements are well-formed', () {
      for (var seed = 0; seed < 30; seed++) {
        final question = TrueFalseQuestionFactory.create(
          DifficultyLevel.hard,
          random: Random(seed),
        );
        if (question.prompt.contains('divisible by')) {
          expect(question.prompt, matches(RegExp(r'^\d+ is divisible by \d+$')));
        }
      }
    });
  });
}
