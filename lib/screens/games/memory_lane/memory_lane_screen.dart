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
import 'memory_lane_controller.dart';

class MemoryLaneScreen extends StatefulWidget {
  const MemoryLaneScreen({super.key, required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  State<MemoryLaneScreen> createState() => _MemoryLaneScreenState();
}

class _MemoryLaneScreenState extends State<MemoryLaneScreen> {
  late final MemoryLaneController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = MemoryLaneController(
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
        final totalTiles = _controller.gridSize * _controller.gridSize;

        return Scaffold(
          appBar: CustomAppBar(
            title: 'Memory Lane',
            subtitle: '${widget.difficulty.title} (${_controller.gridSize}x${_controller.gridSize})',
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TimerBar(
                          progress: _controller.progress,
                          secondsRemaining: _controller.secondsRemaining,
                        ),
                        const SizedBox(height: 14),
                        GameStatusHeader(
                          game: GameType.memoryLane,
                          score: _controller.score,
                          streak: _controller.currentStreak,
                          correctAnswers: _controller.correctAnswers,
                          remainingSeconds: _controller.secondsRemaining,
                        ),
                        const SizedBox(height: 14),
                        // State Indicator Message
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _controller.isTouchEnabled
                                // ignore: deprecated_member_use
                                ? BrandPalette.successGreen.withOpacity(0.12)
                                // ignore: deprecated_member_use
                                : BrandPalette.energyOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _controller.isTouchEnabled
                                  // ignore: deprecated_member_use
                                  ? BrandPalette.successGreen.withOpacity(0.4)
                                  // ignore: deprecated_member_use
                                  : BrandPalette.energyOrange.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _controller.isTouchEnabled
                                ? '★ GO! Repeat the pattern! ★'
                                : '⚠ WATCH THE LIGHTS FLASH... ⚠',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _controller.isTouchEnabled
                                  ? BrandPalette.successGreen
                                  : BrandPalette.energyOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Level ${_controller.level}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Length: ${_controller.sequenceLength} Blocks',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Memory Grid
                        Center(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Card(
                              margin: EdgeInsets.zero,
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _controller.gridSize,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: totalTiles,
                                  itemBuilder: (context, index) {
                                    final isFlashing = _controller.flashingTileIndex == index;

                                    // Custom colors for different tiles to make it vibrant!
                                    final tileColor = isFlashing
                                        ? _colorForIndex(index)
                                        : (isDark ? BrandPalette.cardDark : const Color(0xFFE2EFF5));

                                    return Material(
                                      color: tileColor,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: _controller.isTouchEnabled
                                            ? () => _controller.tapTile(index)
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Center(
                                          child: isFlashing
                                              ? Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.white,
                                                  size: _controller.gridSize == 5 ? 24 : 32,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Color _colorForIndex(int index) {
    // Generate beautiful sequential colors based on block positions
    final colors = [
      BrandPalette.electricBlue,
      BrandPalette.energyOrange,
      BrandPalette.successGreen,
      const Color(0xFF7C3AED), // vibrant purple
      const Color(0xFFEC4899), // vibrant pink
      const Color(0xFFFBBF24), // amber yellow
    ];
    return colors[index % colors.length];
  }
}
