import 'dart:math';

import '../../../core/game/timed_game_controller.dart';
import '../../../models/game_model.dart';
import '../../../models/question_model.dart';

class TrueFalseController extends TimedGameController {
  TrueFalseController({
    required super.storage,
    required super.soundService,
    required super.difficulty,
    super.random,
  }) : super(gameType: GameType.trueFalse);

  @override
  QuestionModel buildQuestion() {
    return TrueFalseQuestionFactory.create(difficulty, random: random);
  }
}

enum _FactType { arithmetic, shapes, numberFacts }

class TrueFalseQuestionFactory {
  static QuestionModel create(
    DifficultyLevel difficulty, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final factType = _FactType.values[rng.nextInt(_FactType.values.length)];
    final isTrueStatement = rng.nextBool();

    late final String prompt;

    switch (factType) {
      case _FactType.arithmetic:
        prompt = _buildArithmetic(difficulty, rng, isTrueStatement);
      case _FactType.shapes:
        prompt = _buildShapeFact(rng, isTrueStatement);
      case _FactType.numberFacts:
        prompt = _buildNumberFact(difficulty, rng, isTrueStatement);
    }

    return QuestionModel(
      prompt: prompt,
      correctAnswer: isTrueStatement ? 'True' : 'False',
      options: const ['True', 'False'],
    );
  }

  static String _buildArithmetic(
    DifficultyLevel difficulty,
    Random rng,
    bool isTrueStatement,
  ) {
    final maxNumber = switch (difficulty) {
      DifficultyLevel.easy => 12,
      DifficultyLevel.medium => 25,
      DifficultyLevel.hard => 50,
    };
    final useMultiply = difficulty != DifficultyLevel.easy && rng.nextBool();
    final useDivide = difficulty == DifficultyLevel.hard && rng.nextBool();

    int left;
    int right;
    int correctResult;
    String symbol;

    if (useDivide) {
      right = rng.nextInt(8) + 2;
      final quotient = rng.nextInt(11) + 2;
      left = right * quotient;
      correctResult = quotient;
      symbol = '÷';
    } else if (useMultiply) {
      left = rng.nextInt(10) + 2;
      right = rng.nextInt(10) + 2;
      correctResult = left * right;
      symbol = '×';
    } else {
      left = rng.nextInt(maxNumber) + 1;
      right = rng.nextInt(maxNumber) + 1;
      if (rng.nextBool()) {
        correctResult = left + right;
        symbol = '+';
      } else {
        if (left < right) {
          final temp = left;
          left = right;
          right = temp;
        }
        correctResult = left - right;
        symbol = '-';
      }
    }

    final shownResult = isTrueStatement
        ? correctResult
        : correctResult + (rng.nextBool() ? 1 : -1) * (rng.nextInt(3) + 1);
    return '$left $symbol $right = $shownResult';
  }

  static String _buildShapeFact(Random rng, bool isTrueStatement) {
    final facts = <String, int>{
      'triangle': 3,
      'square': 4,
      'pentagon': 5,
      'hexagon': 6,
    }.entries.toList();
    final selected = facts[rng.nextInt(facts.length)];
    final shownSides = isTrueStatement
        ? selected.value
        : selected.value + (rng.nextBool() ? 1 : -1);
    return 'A ${selected.key} has $shownSides sides';
  }

  static String _buildNumberFact(
    DifficultyLevel difficulty,
    Random rng,
    bool isTrueStatement,
  ) {
    if (difficulty == DifficultyLevel.hard && rng.nextBool()) {
      final number = [9, 12, 15, 18, 21][rng.nextInt(5)];
      final divisor = [3, 4, 5][rng.nextInt(3)];
      final truth = number % divisor == 0;
      final statementTruth = isTrueStatement ? truth : !truth;
      if (statementTruth) {
        return '$number is divisible by $divisor';
      }
      final wrongDivisor = divisor + (rng.nextBool() ? 1 : 2);
      return '$number is divisible by $wrongDivisor';
    }

    final number = rng.nextInt(difficulty == DifficultyLevel.easy ? 20 : 60) + 1;
    final shouldBeEven = rng.nextBool();
    final truth = shouldBeEven ? number.isEven : number.isOdd;
    final adjective = shouldBeEven ? 'even' : 'odd';
    final finalTruth = isTrueStatement ? truth : !truth;
    if (finalTruth == truth) {
      return '$number is an $adjective number';
    }
    final flippedAdjective = shouldBeEven ? 'odd' : 'even';
    return '$number is an $flippedAdjective number';
  }
}
