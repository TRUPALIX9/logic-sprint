import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.showFeedback,
    required this.isCorrectChoice,
    required this.isSelected,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showFeedback;
  final bool isCorrectChoice;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = showFeedback
        ? isCorrectChoice
              ? AppColors.success.withValues(alpha: 0.16)
              : isSelected
              ? AppColors.danger.withValues(alpha: 0.18)
              : colors.surfaceContainerHighest
        : colors.surfaceContainerHighest;
    final borderColor = showFeedback
        ? isCorrectChoice
              ? AppColors.success
              : isSelected
              ? AppColors.danger
              : Colors.transparent
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
