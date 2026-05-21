class QuestionModel {
  const QuestionModel({
    required this.prompt,
    required this.correctAnswer,
    required this.options,
    this.helperText,
  });

  final String prompt;
  final String correctAnswer;
  final List<String> options;
  final String? helperText;
}
