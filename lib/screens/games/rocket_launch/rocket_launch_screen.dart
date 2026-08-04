import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/brand_palette.dart';
import '../../../core/constants/app_routes.dart';
import '../../../models/game_model.dart';
import '../../../services/ad_service.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/game_status_header.dart';
import '../../../widgets/timer_bar.dart';
import 'rocket_launch_controller.dart';

class RocketLaunchScreen extends StatefulWidget {
  const RocketLaunchScreen({super.key, required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  State<RocketLaunchScreen> createState() => _RocketLaunchScreenState();
}

class _RocketLaunchScreenState extends State<RocketLaunchScreen> {
  late final RocketLaunchController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = RocketLaunchController(
      storage: context.read<LocalStorageService>(),
      soundService: context.read<SoundService>(),
      difficulty: widget.difficulty,
    )..addListener(_handleControllerUpdate);
    unawaited(_controller.initialize());
  }

  Future<void> _handleControllerUpdate() async {
    if (_didNavigate || !_controller.isRoundComplete || _controller.result == null) {
      return;
    }

    _didNavigate = true;
    await context.read<AppState>().recordHighScore(
          _controller.gameType,
          widget.difficulty,
          _controller.score,
        );
    if (!mounted) {
      return;
    }

    context.read<AdService>().showInterstitialAd(
      context: context,
      onAdClosed: () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.result,
            arguments: _controller.result,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark ? BrandPalette.surfaceDark : const Color(0xFF0F0C20),
          appBar: CustomAppBar(
            title: 'Rocket Launch',
            subtitle: widget.difficulty.title,
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            TimerBar(
                              progress: _controller.progress,
                              secondsRemaining: _controller.secondsRemaining,
                            ),
                            const SizedBox(height: 12),
                            GameStatusHeader(
                              game: GameType.rocketLaunch,
                              score: _controller.score,
                              streak: _controller.currentStreak,
                              correctAnswers: _controller.correctAnswers,
                              remainingSeconds: _controller.secondsRemaining,
                            ),
                          ],
                        ),
                      ),
                      // Game Playing Field
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final height = constraints.maxHeight;

                            return GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                // Drag control for rocket
                                final localX = details.localPosition.dx;
                                final normalizedX = (localX / width).clamp(0.05, 0.95);
                                _controller.moveRocketTo(normalizedX);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // Space Star Background (Static stars for performance)
                                    const Positioned.fill(child: _StarryBackground()),

                                    // Display asteroids
                                    for (final asteroid in _controller.asteroids)
                                      Positioned(
                                        left: asteroid.x * width - (asteroid.size / 2),
                                        top: asteroid.y * height - (asteroid.size / 2),
                                        child: Icon(
                                          Icons.blur_on_rounded,
                                          size: asteroid.size,
                                          color: Colors.grey[400],
                                        ),
                                      ),

                                    // Rocket Ship at y = 0.85
                                    Positioned(
                                      left: _controller.rocketX * width - 25,
                                      top: 0.85 * height - 30,
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.rocket_launch_rounded,
                                            size: 50,
                                            color: theme.colorScheme.primary,
                                          ),
                                          // Fire thrust animation representation
                                          const Icon(
                                            Icons.local_fire_department_rounded,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Drag Indicator Text overlay
                                    Positioned(
                                      bottom: 12,
                                      left: 0,
                                      right: 0,
                                      child: Text(
                                        '← Drag screen to steer rocket →',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          // ignore: deprecated_member_use
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Button controls
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              onPressed: _controller.moveRocketLeft,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('LEFT'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              onPressed: _controller.moveRocketRight,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('RIGHT'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _StarryBackground extends StatelessWidget {
  const _StarryBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < 25; i++)
          Positioned(
            left: (i * 17) % 360 / 360 * MediaQuery.of(context).size.width,
            top: (i * 29) % 600 / 600 * MediaQuery.of(context).size.height,
            child: Container(
              width: (i % 3 == 0) ? 3 : 1.5,
              height: (i % 3 == 0) ? 3 : 1.5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
