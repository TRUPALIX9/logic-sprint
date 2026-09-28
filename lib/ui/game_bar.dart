import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/game.dart';
import 'ad_banner.dart';
import 'chamfer.dart';
import 'kit.dart';

/// In-game header, one row: `||` pause (▶ resume while [paused]), an ad
/// banner, and the score. No title, no timer, no back button: pausing is
/// the way out (the paused card has End run).
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.game,
    required this.score,
    required this.paused,
    this.onPause,
    this.onResume,
  });

  /// Keeps the banner clear of the pause button, so a tap meant for it
  /// can't land on the ad.
  static const adGap = 16.0;

  final GameId game;
  final int score;

  /// Swaps pause for resume.
  final bool paused;

  /// Null disables the button (e.g. while the run is down).
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LS.line)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (paused)
                _OutlinedIconButton(
                  icon: Icons.play_arrow_rounded,
                  tooltip: 'Resume',
                  color: LS.teal,
                  onPressed: onResume,
                )
              else
                _OutlinedIconButton(
                  icon: Icons.pause_rounded,
                  tooltip: 'Pause',
                  color: LS.teal,
                  onPressed: onPause,
                ),
              const SizedBox(width: adGap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => AdBanner(
                    width: constraints.maxWidth,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Fixed width, so the banner doesn't resize as the score grows.
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const MonoLabel('Score', size: 10),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$score',
                        style: LSText.mono(
                          22,
                          color: game.accent,
                          weight: FontWeight.w700,
                          spacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44×44 chamfered icon button: transparent fill, border and icon in [color].
class _OutlinedIconButton extends StatelessWidget {
  const _OutlinedIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: ChamferBox(
            cut: Cut.sm,
            width: 44,
            height: 44,
            color: Colors.transparent,
            borderColor: color.withValues(alpha: 0.6),
            onTap: onPressed,
            child: Icon(icon, size: 24, color: color),
          ),
        ),
      ),
    );
  }
}
