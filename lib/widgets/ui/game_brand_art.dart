import 'package:flutter/material.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/brand/game_brand.dart';
import '../../models/game_model.dart';

/// Per-game artwork from the brand kit (dedicated tile or listing fallback).
class GameBrandArt extends StatelessWidget {
  const GameBrandArt({
    super.key,
    required this.game,
    this.size = 40,
    this.borderRadius = 12,
    this.showIconFallback = true,
  });

  final GameType game;
  final double size;
  final double borderRadius;
  final bool showIconFallback;

  @override
  Widget build(BuildContext context) {
    final brand = GameBrand.forGame(game);
    final tilePath = BrandAssets.gameTilePath(game);
    final fallbackPath = BrandAssets.gameListingArt(game);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: brand.iconBackground,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        tilePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          fallbackPath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) {
            if (!showIconFallback) {
              return const SizedBox.shrink();
            }
            return Icon(
              game.icon,
              color: brand.accent,
              size: size * 0.52,
            );
          },
        ),
      ),
    );
  }
}
