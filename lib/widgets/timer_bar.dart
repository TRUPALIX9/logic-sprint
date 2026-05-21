import 'package:flutter/material.dart';

class TimerBar extends StatelessWidget {
  const TimerBar({
    super.key,
    required this.progress,
    required this.secondsRemaining,
  });

  final double progress;
  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Timer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '$secondsRemaining s',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: progress.clamp(0, 1),
          ),
        ),
      ],
    );
  }
}
