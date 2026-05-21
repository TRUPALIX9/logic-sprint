import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand/brand_palette.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: BrandPalette.heroGradient,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLogo(
                      variant: BrandLogoVariant.lockupOnDark,
                      height: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.homeTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.12),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.gameSelect),
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.16),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Mini Games',
                icon: Icons.extension_rounded,
                isSecondary: true,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.gameSelect),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.16),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'High Scores',
                icon: Icons.emoji_events_rounded,
                isSecondary: true,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.highScores),
              ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.16),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Settings',
                icon: Icons.settings_rounded,
                isSecondary: true,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ).animate().fadeIn(delay: 360.ms).slideY(begin: 0.16),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Every round lasts 30 seconds. Move fast, build streaks, and chase your best local score.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 450.ms),
            ],
          ),
        ),
      ),
    );
  }
}
