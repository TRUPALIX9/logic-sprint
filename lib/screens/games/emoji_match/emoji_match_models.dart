class EmojiMatchConfig {
  const EmojiMatchConfig({
    required this.pairCount,
    required this.crossAxisCount,
    required this.mismatchRevealDuration,
  });

  final int pairCount;
  final int crossAxisCount;
  final Duration mismatchRevealDuration;
}

EmojiMatchConfig emojiMatchConfigForLevel(int level) {
  final tier = level.clamp(1, 99);
  final pairCount = switch (tier) {
    <= 1 => 2,
    <= 2 => 3,
    <= 3 => 4,
    <= 4 => 5,
    <= 5 => 6,
    <= 6 => 7,
    _ => 8 + (tier - 7).clamp(0, 4),
  };
  final crossAxisCount = pairCount <= 4
      ? 2
      : pairCount <= 6
      ? 3
      : 4;
  final revealMs = tier >= 5 ? 550 : 750;
  return EmojiMatchConfig(
    pairCount: pairCount,
    crossAxisCount: crossAxisCount,
    mismatchRevealDuration: Duration(milliseconds: revealMs),
  );
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
  '🎮',
  '🌺',
  '🎸',
  '⚡',
];

class EmojiCard {
  EmojiCard({required this.id, required this.emoji});

  final String id;
  final String emoji;
  bool isFaceUp = false;
  bool isMatched = false;
}
