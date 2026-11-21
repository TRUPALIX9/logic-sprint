import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/profile_stats.dart';
import '../../models/run_record.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';

/// One finished run: game icon, title (with difficulty), how long ago,
/// BEST if it set a personal best, time for timed games, and the score.
/// Used by Profile's preview and the History page.
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.run});

  final RunRecord run;

  @override
  Widget build(BuildContext context) {
    final game = run.game;
    return ChamferBox(
      cut: Cut.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GameTile(game: game, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.titleWith(run.difficulty),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LSText.body(15, weight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 3),
                MonoLabel(formatAgo(run.playedAt), size: 10, color: LS.dim),
              ],
            ),
          ),
          if (run.isBest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              color: LS.blue,
              child: const MonoLabel(
                'Best',
                size: 10,
                weight: FontWeight.w700,
                color: LS.bg,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (game.tracksTime) ...[
            MonoLabel(formatDuration(run.duration), size: 10, color: LS.dim),
            const SizedBox(width: 10),
          ],
          Text(
            formatScore(run.score),
            style: LSText.mono(
              17,
              weight: FontWeight.w700,
              spacing: 0,
              color: LS.text,
            ),
          ),
        ],
      ),
    );
  }
}
