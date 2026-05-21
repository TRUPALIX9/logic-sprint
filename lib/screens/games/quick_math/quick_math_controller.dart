import 'dart:math';

import '../../../core/game/timed_game_controller.dart';
import '../../../core/utils/random_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/question_model.dart';

class QuickMathController extends TimedGameController {
  QuickMathController({
    required super.storage,
    required super.soundService,
    required super.difficulty,
    super.random,
  }) : super(gameType: GameType.quickMath);

  @override
  QuestionModel buildQuestion() {
    return QuickMathQuestionFactory.create(difficulty, random: random);
  }
}

enum _MathOperation { addition, subtraction, multiplication, division }

class QuickMathQuestionFactory {
  static QuestionModel create(
    DifficultyLevel difficulty, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final operation = _pickOperation(difficulty, rng);
    final maxNumber = switch (difficulty) {
      DifficultyLevel.easy => 20,
      DifficultyLevel.medium => 50,
      DifficultyLevel.hard => 100,
    };

    late final int left;
    late final int right;
    late final int answer;
    late final String symbol;

    switch (operation) {
      case _MathOperation.addition:
        left = rng.nextInt(maxNumber) + 1;
        right = rng.nextInt(maxNumber) + 1;
        answer = left + right;
        symbol = '+';
      case _MathOperation.subtraction:
        final first = rng.nextInt(maxNumber) + 1;
        final second = rng.nextInt(maxNumber) + 1;
        left = max(first, second);
        right = min(first, second);
        answer = left - right;
        symbol = '-';
      case _MathOperation.multiplication:
        left = rng.nextInt(12) + 2;
        right = rng.nextInt(12) + 2;
        answer = left * right;
        symbol = '×';
      case _MathOperation.division:
        right = rng.nextInt(11) + 2;
        final quotient = rng.nextInt(11) + 2;
        left = right * quotient;
        answer = quotient;
        symbol = '÷';
    }

    final options = buildNearbyUniqueAnswers(
      correctAnswer: answer,
      count: 3,
      random: rng,
      minValue: 0,
      spread: difficulty == DifficultyLevel.hard ? 20 : 10,
    );

    return QuestionModel(
      prompt: '$left $symbol $right = ?',
      correctAnswer: '$answer',
      options: options.map((option) => '$option').toList(),
    );
  }

  static _MathOperation _pickOperation(
    DifficultyLevel difficulty,
    Random random,
  ) {
    final choices = switch (difficulty) {
      DifficultyLevel.easy => [
          _MathOperation.addition,
          _MathOperation.subtraction,
        ],
      DifficultyLevel.medium => [
          _MathOperation.addition,
          _MathOperation.subtraction,
          _MathOperation.multiplication,
        ],
      DifficultyLevel.hard => _MathOperation.values,
    };
    return choices[random.nextInt(choices.length)];
  }
}
