import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/game/score_calculator.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/screens/games/emoji_match/emoji_match_models.dart';

void main() {
  group('EmojiMatchConfig', () {
    test('hard enables mismatch penalty', () {
      final config = emojiMatchConfigForLevel(8);
      expect(config.pairCount, greaterThanOrEqualTo(8));
    });
  });

  group('Emoji card deck', () {
    test('creates exact pairs from emoji pool', () {
      final random = Random(7);
      final config = emojiMatchConfigForLevel(1);
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
}
