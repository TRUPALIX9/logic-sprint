import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/game.dart';
import '../../models/profile_stats.dart';

/// "NEON_FOX#0420" with the code dimmed.
class NameWithTag extends StatelessWidget {
  const NameWithTag({
    super.key,
    required this.name,
    required this.tag,
    required this.size,
  });

  final String name;
  final String? tag;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = LSText.display(size);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: name.toUpperCase()),
          if (tag != null)
            TextSpan(
              text: '#$tag',
              style: style.copyWith(color: LS.dim),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A game's best in its accent colour, or a dim "—".
class BestText extends StatelessWidget {
  const BestText({super.key, required this.stat, required this.size});

  final GameStat stat;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    stat.hasBest ? formatScore(stat.best) : '—',
    maxLines: 1,
    style: LSText.mono(
      size,
      weight: FontWeight.w700,
      spacing: 0,
      color: stat.hasBest ? stat.game.accent : LS.dim,
    ),
  );
}

/// "Hard · #9 · 1:03": difficulty of the best, board rank if known, and
/// best time for timed games. A ramp game with neither shows its skill.
/// Play counts are hidden for now (kept in [GameStat.runs]).
String gameMeta(GameStat stat, {bool withTime = true}) {
  if (!stat.hasBest) {
    return stat.runs == 0 ? 'Not played yet' : 'No score yet';
  }
  final difficulty = stat.difficulty;
  final rank = stat.rank;
  final time = stat.bestTime;
  final parts = [
    if (difficulty != null) _cap(difficulty),
    if (rank != null) '#$rank',
    if (withTime && time != null) formatDuration(time),
  ];
  return parts.isEmpty ? stat.game.skill : parts.join(' · ');
}

/// "E 200 · M 310 · H —" for a game with difficulty and a best; null
/// otherwise.
String? difficultyBreakdown(GameStat stat) {
  if (!stat.game.hasDifficulty || !stat.hasBest) {
    return null;
  }
  return [
    for (final d in Difficulty.values)
      '${d.label[0]} ${(stat.bests[d] ?? 0) > 0 ? formatScore(stat.bests[d]!) : '—'}',
  ].join(' · ');
}

String _cap(Difficulty d) =>
    '${d.label[0]}${d.label.substring(1).toLowerCase()}';
