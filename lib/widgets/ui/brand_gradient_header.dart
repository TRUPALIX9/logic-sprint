import 'package:flutter/material.dart';

import '../../core/brand/brand_palette.dart';
import '../../core/constants/app_strings.dart';
import '../brand_logo.dart';

class BrandGradientHeader extends StatelessWidget {
  const BrandGradientHeader({
    super.key,
    this.subtitle = AppStrings.appSubtitle,
    this.description = AppStrings.homeTagline,
    this.showLogoMark = true,
    this.trailing,
    this.compact = false,
  });

  final String subtitle;
  final String description;
  final bool showLogoMark;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: BrandPalette.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: BrandPalette.primaryNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showLogoMark) ...[
                const BrandLogo(
                  variant: BrandLogoVariant.mark,
                  height: 48,
                  width: 48,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: compact ? 24 : 28,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: BrandPalette.brainCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
