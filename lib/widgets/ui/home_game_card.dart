import 'package:flutter/material.dart';

import '../../core/brand/brand_palette.dart';
import '../../core/brand/game_brand.dart';
import '../../models/game_model.dart';

class HomeGameCard extends StatefulWidget {
  const HomeGameCard({
    super.key,
    required this.game,
    required this.bestScore,
    required this.onTap,
  });

  final GameModel game;
  final int bestScore;
  final VoidCallback onTap;

  @override
  State<HomeGameCard> createState() => _HomeGameCardState();
}

class _HomeGameCardState extends State<HomeGameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brand = GameBrand.forGame(widget.game.type);
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: BrandPalette.brainCyan.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brand.iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.game.emoji ?? '',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.game.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.game.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Best: ${widget.bestScore}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: brand.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
