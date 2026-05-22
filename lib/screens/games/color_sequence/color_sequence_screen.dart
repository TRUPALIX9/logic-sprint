import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/life_game_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/game_model.dart';
import '../../../models/second_life_config.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/app_gradient_background.dart';
import '../../../widgets/game_second_life_layer.dart';
import '../../../widgets/game_screen_shell.dart';
import 'color_sequence_controller.dart';

class ColorSequenceScreen extends StatefulWidget {
  const ColorSequenceScreen({super.key});

  @override
  State<ColorSequenceScreen> createState() => _ColorSequenceScreenState();
}

class _ColorSequenceScreenState extends State<ColorSequenceScreen> {
  late final ColorSequenceController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = ColorSequenceController(
      storage: context.read<LocalStorageService>(),
      soundService: context.read<SoundService>(),
    )..addListener(_handleControllerUpdate);
    unawaited(_controller.initialize());
  }

  Future<void> _onPlayAgain() async {
    _didNavigate = false;
    _controller.resetGame();
    await _controller.initialize();
  }

  Future<void> _handleControllerUpdate() async {
    if (_didNavigate ||
        !_controller.isRoundComplete ||
        _controller.result == null) {
      return;
    }

    _didNavigate = true;
    await context.read<AppState>().recordHighScore(
      GameType.colorSequence,
      LifeGameConstants.storageDifficulty,
      _controller.score,
      highestLevel: _controller.level,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.result, arguments: _controller.result);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  Color _colorFor(SequenceColor color) {
    return switch (color) {
      SequenceColor.blue => const Color(0xFF2563EB),
      SequenceColor.orange => AppColors.accent,
      SequenceColor.cyan => AppColors.brainCyan,
      SequenceColor.purple => const Color(0xFF7C3AED),
    };
  }

  @override
  Widget build(BuildContext context) {
    final config = SecondLifeConfig.forGame(GameType.colorSequence);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GameSecondLifeLayer(
          config: config,
          session: _controller.secondLife,
          score: _controller.score,
          bestScore: _controller.bestScore,
          onEndGameFinal: _controller.endGameFinal,
          onPlayAgain: _onPlayAgain,
          onResumeFromSecondLife: _controller.resumeFromSecondLifeReward,
          child: GameScreenShell(
            title: 'Color Sequence',
            score: _controller.score,
            lives: _controller.lives,
            level: _controller.level,
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ThemedGamePanel(
                          accent: const Color(0xFFC026D3),
                          child: Column(
                            children: [
                              Text(
                                _controller.instruction,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppGradientBackground.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _SequencePreview(
                                sequence: _controller.targetSequence,
                                highlightedIndex: _controller.highlightedIndex,
                                colorFor: _colorFor,
                                dimmed:
                                    _controller.phase ==
                                    ColorSequencePhase.repeating,
                              ),
                              if (_controller.feedbackMessage case final msg?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    msg,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: msg == 'Correct!'
                                              ? AppColors.success
                                              : AppGradientBackground.lifeLost,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.35,
                            children: ColorSequenceController.palette.map((
                              color,
                            ) {
                              return _ColorTapButton(
                                label: color.label,
                                color: _colorFor(color),
                                enabled: _controller.canTapColors,
                                onPressed: () =>
                                    unawaited(_controller.tapColor(color)),
                              );
                            }).toList(),
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
}

class _SequencePreview extends StatelessWidget {
  const _SequencePreview({
    required this.sequence,
    required this.highlightedIndex,
    required this.colorFor,
    required this.dimmed,
  });

  final List<SequenceColor> sequence;
  final int? highlightedIndex;
  final Color Function(SequenceColor) colorFor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (sequence.isEmpty) {
      return const SizedBox(height: 36);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (var i = 0; i < sequence.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppGradientBackground.textSecondary,
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorFor(sequence[i]).withValues(
                alpha: highlightedIndex == i ? 1 : (dimmed ? 0.35 : 0.85),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ],
    );
  }
}

class _ColorTapButton extends StatelessWidget {
  const _ColorTapButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: enabled ? 0.92 : 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
