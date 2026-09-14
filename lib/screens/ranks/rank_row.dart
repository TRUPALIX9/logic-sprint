import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/leaderboard_entry.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';

/// One 56 px leaderboard row: rank, name (+ YOU), a dim detail line (when
/// the best was set) with an optional movement chip, the run time for timed
/// games, and the score.
class RankRow extends StatelessWidget {
  const RankRow({
    super.key,
    required this.rank,
    required this.name,
    required this.score,
    this.time,
    this.isYou = false,
    this.detail,
    this.move,
    this.chipOpacity = 1,
  });

  static const height = 56.0;

  final int rank;
  final String name;
  final int score;

  /// Only for games that track time (Memory Lane, Quick Math).
  final Duration? time;
  final bool isYou;

  /// "2 h ago", "#1 since Sep 10", "Your best · set Sep 12".
  final String? detail;

  /// Movement chip (▲3 / ▼1 / NEW); none for [RankMoveKind.same].
  final RankMove? move;
  final double chipOpacity;

  @override
  Widget build(BuildContext context) {
    final highlight = rank == 1 ? LS.blue : (isYou ? LS.teal : null);
    final time = this.time;
    final detail = this.detail;
    final move = this.move;
    final showChip = move != null && move.kind != RankMoveKind.same;
    return ChamferBox(
      cut: Cut.sm,
      height: height,
      color: highlight?.withValues(alpha: 0.06) ?? LS.surface,
      borderColor: highlight?.withValues(alpha: 0.55) ?? LS.line,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rank > 10 ? '#$rank' : '$rank'.padLeft(2, '0'),
                style: LSText.mono(
                  16,
                  weight: FontWeight.w700,
                  spacing: 0,
                  color: rank == 1 ? LS.blue : (isYou ? LS.teal : LS.muted),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LSText.body(
                          16,
                          weight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        color: LS.teal,
                        child: const MonoLabel(
                          'You',
                          size: 10,
                          weight: FontWeight.w700,
                          color: LS.bg,
                        ),
                      ),
                    ],
                  ],
                ),
                if (detail != null || showChip) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (showChip) ...[
                        Opacity(opacity: chipOpacity, child: MoveChip(move)),
                        const SizedBox(width: 6),
                      ],
                      if (detail != null)
                        Flexible(
                          child: Text(
                            detail.toUpperCase(),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: LSText.mono(10, color: LS.dim),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (time != null) ...[
            const SizedBox(width: 8),
            MonoLabel(formatDuration(time), size: 10, color: LS.dim),
          ],
          const SizedBox(width: 12),
          Text(
            '$score',
            style: LSText.mono(
              18,
              weight: FontWeight.w700,
              spacing: 0,
              color: highlight ?? LS.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Teal "▲3" for climbers, dim "▼1" for fallers, gold "NEW" for entrants.
class MoveChip extends StatelessWidget {
  const MoveChip(this.move, {super.key});

  final RankMove move;

  @override
  Widget build(BuildContext context) {
    final (label, semantics, color) = switch (move.kind) {
      RankMoveKind.up => ('▲${move.places}', 'Up ${move.places}', LS.teal),
      RankMoveKind.down => ('▼${move.places}', 'Down ${move.places}', LS.dim),
      RankMoveKind.entered => ('NEW', 'New entry', LS.gold),
      RankMoveKind.same => ('', '', LS.dim),
    };
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        color: color.withValues(alpha: 0.14),
        child: Text(
          label,
          style: LSText.mono(
            9.5,
            color: color,
            weight: FontWeight.w700,
            spacing: 0.04,
          ),
        ),
      ),
    );
  }
}
