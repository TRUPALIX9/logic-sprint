import '../../../models/game_model.dart';

class EmojiMatchConfig {
  const EmojiMatchConfig({
    required this.pairCount,
    required this.crossAxisCount,
    required this.totalTime,
    required this.mismatchRevealDuration,
    required this.hasMismatchPenalty,
  });

  final int pairCount;
  final int crossAxisCount;
  final Duration totalTime;
  final Duration mismatchRevealDuration;
  final bool hasMismatchPenalty;
}

EmojiMatchConfig emojiMatchConfigFor(DifficultyLevel difficulty) {
  switch (difficulty) {
    case DifficultyLevel.easy:
      return const EmojiMatchConfig(
        pairCount: 6,
        crossAxisCount: 3,
        totalTime: Duration(seconds: 60),
        mismatchRevealDuration: Duration(milliseconds: 900),
        hasMismatchPenalty: false,
      );
    case DifficultyLevel.medium:
      return const EmojiMatchConfig(
        pairCount: 8,
        crossAxisCount: 4,
        totalTime: Duration(seconds: 45),
        mismatchRevealDuration: Duration(milliseconds: 750),
        hasMismatchPenalty: false,
      );
    case DifficultyLevel.hard:
      return const EmojiMatchConfig(
        pairCount: 10,
        crossAxisCount: 4,
        totalTime: Duration(seconds: 30),
        mismatchRevealDuration: Duration(milliseconds: 600),
        hasMismatchPenalty: true,
      );
  }
}

const List<String> emojiPool = [
  '🍎',
  '🐶',
  '🚗',
  '⚽',
  '🌟',
  '🎵',
  '🍕',
  '🐱',
  '🚀',
  '🌈',
  '🧠',
  '🎯',
  '📚',
  '🦊',
  '🍩',
  '🏀',
];

class EmojiCard {
  EmojiCard({required this.id, required this.emoji});

  final String id;
  final String emoji;
  bool isFaceUp = false;
  bool isMatched = false;
}
