import 'package:flutter/material.dart';

import 'app_gradient_background.dart';
import 'game_lives_hud.dart';

/// Gradient game screen wrapper with standard HUD.
class GameScreenShell extends StatelessWidget {
  const GameScreenShell({
    super.key,
    required this.title,
    required this.score,
    required this.lives,
    required this.child,
    this.maxLives = 3,
    this.level,
    this.onBack,
    this.bottom,
  });

  final String title;
  final int score;
  final int lives;
  final int maxLives;
  final int? level;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                child: GameLivesHud(
                  title: title,
                  score: score,
                  lives: lives,
                  maxLives: maxLives,
                  level: level,
                  onBack: onBack,
                ),
              ),
              Expanded(child: child),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }
}
