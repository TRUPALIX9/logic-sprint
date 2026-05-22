import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/game/score_calculator.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/emoji_match/emoji_match_models.dart';

void main() {
  group('EmojiMatchConfig', () {
    test('hard enables mismatch penalty', () {
      final config = emojiMatchConfigFor(DifficultyLevel.hard);
      expect(config.hasMismatchPenalty, isTrue);
      expect(config.pairCount, 10);
    });
  });

  group('Emoji card deck', () {
    test('creates exact pairs from emoji pool', () {
      final random = Random(7);
      final config = emojiMatchConfigFor(DifficultyLevel.easy);
      final selectedEmojis = [...emojiPool]..shuffle(random);
      final pairs = selectedEmojis.take(config.pairCount).toList();
      final cards = [
        for (final emoji in pairs) ...[
          EmojiCard(id: '${emoji}_a', emoji: emoji),
          EmojiCard(id: '${emoji}_b', emoji: emoji),
        ],
      ];

      expect(cards, hasLength(config.pairCount * 2));
      final counts = <String, int>{};
      for (final card in cards) {
        counts[card.emoji] = (counts[card.emoji] ?? 0) + 1;
      }
      for (final count in counts.values) {
        expect(count, 2);
      }
    });
  });

  group('Emoji Match scoring', () {
    test('hard penalty reduces score by 2', () {
      expect(ScoreCalculator.applyMismatchPenalty(5, penalty: 2), 3);
      expect(ScoreCalculator.applyMismatchPenalty(1, penalty: 2), 0);
    });
  });
}
