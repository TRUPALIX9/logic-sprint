import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand/brand_palette.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: BrandPalette.splashGradient,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(
                  variant: BrandLogoVariant.mark,
                  height: 120,
                )
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 350.ms),
                const SizedBox(height: 20),
                const BrandLogo(
                  variant: BrandLogoVariant.lockupOnDark,
                  height: 56,
                  width: 280,
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.12),
                const SizedBox(height: 18),
                Text(
                  AppStrings.homeTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 28),
                const CircularProgressIndicator(
                  color: AppColors.accent,
                ).animate().fadeIn(delay: 650.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
