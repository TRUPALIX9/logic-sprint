import 'package:flutter/material.dart';

import '../core/brand/brand_assets.dart';

/// Renders official PNG brand artwork from the asset kit.
enum BrandLogoVariant {
  /// Brain mark only — splash, about, compact headers.
  mark,

  /// Full wordmark on dark backgrounds (home hero, splash).
  lockupOnDark,

  /// Full wordmark on light backgrounds.
  lockupOnLight,

  /// Transparent lockup for mixed surfaces.
  lockupTransparent,
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.variant,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  final BrandLogoVariant variant;
  final double? height;
  final double? width;
  final BoxFit fit;

  String get _assetPath {
    switch (variant) {
      case BrandLogoVariant.mark:
        return BrandAssets.logoMark;
      case BrandLogoVariant.lockupOnDark:
        return BrandAssets.lockupOnDark;
      case BrandLogoVariant.lockupOnLight:
        return BrandAssets.lockupOnLight;
      case BrandLogoVariant.lockupTransparent:
        return BrandAssets.lockupTransparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        Icons.psychology_alt_rounded,
        size: height ?? 48,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
