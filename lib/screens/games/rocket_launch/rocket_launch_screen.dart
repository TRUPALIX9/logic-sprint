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
import '../../../widgets/ui/game_tactile_button.dart';
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
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFF10BDEB).withValues(alpha: 0.5),
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10BDEB).withValues(alpha: 0.15),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
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
                                          color: Colors.white.withValues(alpha: 0.5),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: GameTactileButton(
                                color: const Color(0xFF10BDEB),
                                bottomColor: const Color(0xFF0B8EA1),
                                height: 52,
                                onPressed: _controller.moveRocketLeft,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('STEER LEFT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GameTactileButton(
                                color: const Color(0xFF10BDEB),
                                bottomColor: const Color(0xFF0B8EA1),
                                height: 52,
                                onPressed: _controller.moveRocketRight,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('STEER RIGHT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                                  ],
                                ),
                              ),
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
        for (var i = 0; i < 35; i++)
          Positioned(
            left: (i * 23) % 360 / 360 * MediaQuery.of(context).size.width,
            top: (i * 31) % 600 / 600 * MediaQuery.of(context).size.height,
            child: Opacity(
              opacity: (i % 2 == 0) ? 0.85 : 0.4,
              child: Container(
                width: (i % 5 == 0) ? 4.0 : (i % 3 == 0) ? 2.5 : 1.5,
                height: (i % 5 == 0) ? 4.0 : (i % 3 == 0) ? 2.5 : 1.5,
                decoration: BoxDecoration(
                  color: (i % 4 == 0)
                      ? const Color(0xFF45D7FF) // cyan star
                      : (i % 7 == 0)
                          ? const Color(0xFFFF8A00) // orange star hint
                          : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: (i % 5 == 0)
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
