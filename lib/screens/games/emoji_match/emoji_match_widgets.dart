import 'package:flutter/material.dart';

import '../../../core/brand/brand_palette.dart';
import 'emoji_match_models.dart';

class EmojiCardTile extends StatelessWidget {
  const EmojiCardTile({super.key, required this.card, required this.onTap});

  final EmojiCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showEmoji = card.isFaceUp || card.isMatched;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: showEmoji ? BrandPalette.softBackground : BrandPalette.deepPurple,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: card.isMatched
                ? BrandPalette.electricBlue
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              showEmoji ? card.emoji : '?',
              key: ValueKey(showEmoji ? card.emoji : '?'),
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
      ),
    );
  }
}
