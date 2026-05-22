import 'package:flutter/material.dart';

import '../models/game_model.dart';
import '../models/leaderboard_entry.dart';
import 'app_gradient_background.dart';

class LeaderboardTile extends StatelessWidget {
  const LeaderboardTile({super.key, required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateLabel = entry.updatedAt == null
        ? ''
        : ' · ${entry.updatedAt!.month}/${entry.updatedAt!.day}/${entry.updatedAt!.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0D1B3D).withValues(alpha: 0.72),
        border: Border.all(
          color: AppGradientBackground.cyanAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppGradientBackground.cyanAccent.withValues(
              alpha: 0.2,
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppGradientBackground.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.playerName,
                        style: const TextStyle(
                          color: AppGradientBackground.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.score}',
                      style: const TextStyle(
                        color: AppGradientBackground.cyanAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Level ${entry.level} · ${entry.gameType.title}$dateLabel',
                  style: const TextStyle(
                    color: AppGradientBackground.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
