import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../models/game_model.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/game_status_header.dart';
import '../../../widgets/timer_bar.dart';
import 'color_sequence_controller.dart';

class ColorSequenceScreen extends StatefulWidget {
  const ColorSequenceScreen({super.key, required this.difficulty});

  final DifficultyLevel difficulty;

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
      difficulty: widget.difficulty,
    )..addListener(_handleControllerUpdate);
    unawaited(_controller.initialize());
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
      widget.difficulty,
      _controller.score,
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'Color Sequence',
            subtitle: widget.difficulty.title,
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
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
                        game: GameType.colorSequence,
                        score: _controller.score,
                        streak: _controller.currentStreak,
                        correctAnswers: _controller.correctAnswers,
                        round: _controller.roundNumber,
                        remainingSeconds: _controller.secondsRemaining,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Round ${_controller.roundNumber}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Length ${_controller.sequenceLength}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Text(
                                _controller.instruction,
                                style: Theme.of(context).textTheme.titleMedium,
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
                              const SizedBox(height: 12),
                              _ProgressDots(
                                length: _controller.sequenceLength,
                                filled: _controller.playerSequence.length,
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
                                              : AppColors.danger,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Repeat the sequence',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: ColorSequenceController.palette.map((color) {
                          final isHighlighted =
                              _controller.highlightedIndex != null &&
                              _controller.phase ==
                                  ColorSequencePhase.watching &&
                              _controller.targetSequence.length >
                                  _controller.highlightedIndex! &&
                              _controller.targetSequence[_controller
                                      .highlightedIndex!] ==
                                  color;

                          return _ColorTapButton(
                            label: color.label,
                            color: _colorFor(color),
                            enabled: _controller.canTapColors,
                            highlighted: isHighlighted,
                            onPressed: () =>
                                unawaited(_controller.tapColor(color)),
                          );
                        }).toList(),
                      ),
                    ],
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
      runSpacing: 8,
      children: [
        for (var i = 0; i < sequence.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Theme.of(context).textTheme.bodySmall?.color,
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
              border: highlightedIndex == i
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: highlightedIndex == i
                  ? [
                      BoxShadow(
                        color: colorFor(sequence[i]).withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final active = index < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.primary
                : AppColors.textMuted.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

class _ColorTapButton extends StatelessWidget {
  const _ColorTapButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.highlighted,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: enabled ? (highlighted ? 1 : 0.92) : 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
