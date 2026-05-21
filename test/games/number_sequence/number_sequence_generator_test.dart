import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/number_sequence/number_sequence_controller.dart';

void main() {
  group('NumberSequenceQuestionFactory', () {
    test('creates four unique options including the answer', () {
      final question = NumberSequenceQuestionFactory.create(
        DifficultyLevel.easy,
        random: Random(7),
      );

      expect(question.options, hasLength(4));
      expect(question.options.toSet(), hasLength(4));
      expect(question.options, contains(question.correctAnswer));
    });

    test('sequence prompt always ends with question mark', () {
      final question = NumberSequenceQuestionFactory.create(
        DifficultyLevel.hard,
        random: Random(9),
      );

      expect(question.prompt, endsWith('?'));
    });
  });
}
