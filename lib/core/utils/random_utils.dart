import 'dart:math';

List<T> shuffledList<T>(List<T> values, [Random? random]) {
  final copy = List<T>.from(values);
  copy.shuffle(random);
  return copy;
}

List<int> buildNearbyUniqueAnswers({
  required int correctAnswer,
  required int count,
  Random? random,
  int minValue = 0,
  int spread = 12,
}) {
  final rng = random ?? Random();
  final answers = <int>{correctAnswer};

  while (answers.length < count + 1) {
    final delta = rng.nextInt(spread * 2 + 1) - spread;
    final candidate = (correctAnswer + delta).clamp(minValue, 9999);
    if (candidate != correctAnswer) {
      answers.add(candidate);
    }
  }

  return answers.toList()..shuffle(rng);
}
