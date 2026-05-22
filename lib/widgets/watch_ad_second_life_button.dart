import 'package:flutter/material.dart';

import '../models/second_life_config.dart';

class WatchAdSecondLifeButton extends StatelessWidget {
  const WatchAdSecondLifeButton({
    super.key,
    required this.onPressed,
    required this.adReady,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool adReady;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: adReady && !isLoading ? onPressed : null,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_circle_outline_rounded),
          label: Text(SecondLifeConfig.watchAdButtonLabel),
        ),
        const SizedBox(height: 6),
        Text(
          adReady
              ? SecondLifeConfig.helperText
              : 'Ad is loading. Try again in a moment or end the game.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
