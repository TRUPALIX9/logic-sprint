import 'dart:math';

import '../../../core/game/timed_game_controller.dart';
import '../../../core/utils/random_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/question_model.dart';

class NumberSequenceController extends TimedGameController {
  NumberSequenceController({
    required super.storage,
    required super.soundService,
    required super.difficulty,
    super.random,
  }) : super(gameType: GameType.numberSequence);

  @override
  QuestionModel buildQuestion() {
    return NumberSequenceQuestionFactory.create(difficulty, random: random);
  }
}

enum _SequencePatternType { addition, subtraction, multiplication, square, alternating }

class NumberSequenceQuestionFactory {
  static QuestionModel create(
    DifficultyLevel difficulty, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final pattern = _pickPattern(difficulty, rng);

    late final List<int> sequence;
    late final int answer;
    late final String helperText;

    switch (pattern) {
      case _SequencePatternType.addition:
        final start = rng.nextInt(12) + 1;
        final step = [2, 3, 4, 5][rng.nextInt(4)];
        sequence = List<int>.generate(4, (index) => start + (step * index));
        answer = start + (step * 4);
        helperText = 'Add $step each time';
      case _SequencePatternType.subtraction:
        final step = [2, 3, 5][rng.nextInt(3)];
        final start = rng.nextInt(30) + (step * 4) + 8;
        sequence = List<int>.generate(4, (index) => start - (step * index));
        answer = start - (step * 4);
        helperText = 'Subtract $step each time';
      case _SequencePatternType.multiplication:
        final start = rng.nextInt(4) + 1;
        final factor = [2, 3][rng.nextInt(2)];
        sequence = List<int>.generate(4, (index) => start * pow(factor, index).toInt());
        answer = start * pow(factor, 4).toInt();
        helperText = 'Multiply by $factor';
      case _SequencePatternType.square:
        final start = rng.nextInt(3) + 1;
        sequence = List<int>.generate(4, (index) {
          final value = start + index;
          return value * value;
        });
        final next = start + 4;
        answer = next * next;
        helperText = 'Square numbers';
      case _SequencePatternType.alternating:
        final start = rng.nextInt(12) + 2;
        final stepA = rng.nextInt(3) + 2;
        final stepB = rng.nextInt(3) + 3;
        sequence = [start];
        while (sequence.length < 4) {
          final previous = sequence.last;
          final index = sequence.length - 1;
          final step = index.isEven ? stepA : stepB;
          sequence.add(previous + step);
        }
        answer = sequence.last + stepB;
        helperText = 'Alternating +$stepA and +$stepB';
    }

    final options = buildNearbyUniqueAnswers(
      correctAnswer: answer,
      count: 3,
      random: rng,
      minValue: 0,
      spread: difficulty == DifficultyLevel.hard ? 18 : 10,
    );

    return QuestionModel(
      prompt: '${sequence.join(', ')}, ?',
      correctAnswer: '$answer',
      options: options.map((option) => '$option').toList(),
      helperText: helperText,
    );
  }

  static _SequencePatternType _pickPattern(
    DifficultyLevel difficulty,
    Random random,
  ) {
    final choices = switch (difficulty) {
      DifficultyLevel.easy => [
          _SequencePatternType.addition,
          _SequencePatternType.subtraction,
        ],
      DifficultyLevel.medium => [
          _SequencePatternType.addition,
          _SequencePatternType.subtraction,
          _SequencePatternType.multiplication,
        ],
      DifficultyLevel.hard => [
          _SequencePatternType.multiplication,
          _SequencePatternType.square,
          _SequencePatternType.alternating,
          _SequencePatternType.addition,
        ],
    };
    return choices[random.nextInt(choices.length)];
  }
}
