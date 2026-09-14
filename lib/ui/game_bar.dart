import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/game.dart';
import 'kit.dart';

/// In-game header: back, game + difficulty, score, and a pause button when
/// [onPause] is given. No timer, no stat cards.
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.game,
    required this.subtitle,
    required this.score,
    this.onPause,
  });

  final GameId game;
  final String subtitle;
  final int score;

  /// Shows a pause button at the end of the bar.
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final onPause = this.onPause;
    return Container(
      height: 64,
      padding: EdgeInsets.only(left: 8, right: onPause == null ? 20 : 8),
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
          if (onPause != null) ...[
            const SizedBox(width: 10),
            LSIconButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              onPressed: onPause,
            ),
          ],
        ],
      ),
    );
  }
}
