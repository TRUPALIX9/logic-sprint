import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/game.dart';
import 'kit.dart';

/// In-game header: back, game + difficulty, score. No timer, no stat cards.
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.game,
    required this.subtitle,
    required this.score,
  });

  final GameId game;
  final String subtitle;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 8, right: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LS.line)),
      ),
      child: Row(
        children: [
          LSIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Quit round',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DisplayText(game.title, size: 22, maxLines: 1),
                const SizedBox(height: 3),
                MonoLabel(subtitle),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const MonoLabel('Score', size: 10),
              const SizedBox(height: 3),
              Text(
                '$score',
                style: LSText.mono(
                  26,
                  color: game.accent,
                  weight: FontWeight.w700,
                  spacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
