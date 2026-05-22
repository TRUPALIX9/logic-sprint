import 'package:flutter/material.dart';

import '../../models/game_model.dart';
import '../../models/home_game_card_theme.dart';

class HomeGameCard extends StatefulWidget {
  const HomeGameCard({
    super.key,
    required this.game,
    required this.bestScore,
    required this.highestLevel,
    required this.onTap,
  });

  final GameModel game;
  final int bestScore;
  final int highestLevel;
  final VoidCallback onTap;

  @override
  State<HomeGameCard> createState() => _HomeGameCardState();
}

class _HomeGameCardState extends State<HomeGameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = HomeGameCardTheme.forGame(widget.game.type);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.glow.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.glow.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.iconBackground.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          widget.game.emoji ?? '',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.game.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFFFFFFFF),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.game.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(
                                      0xFFFFFFFF,
                                    ).withValues(alpha: 0.88),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Best: ${widget.bestScore}  ·  Highest Level: ${widget.highestLevel}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: theme.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFFFFFFF,
                          ).withValues(alpha: 0.18),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFFFFFFFF),
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
