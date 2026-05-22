import 'dart:async';

import 'package:flutter/material.dart';

import '../models/second_life_config.dart';
import '../models/second_life_session.dart';
import '../services/rewarded_ad_service.dart';
import 'game_over_continue_overlay.dart';

/// Wraps an in-game screen with optional rewarded second-life overlay.
class GameSecondLifeLayer extends StatefulWidget {
  const GameSecondLifeLayer({
    super.key,
    required this.config,
    required this.session,
    required this.score,
    required this.bestScore,
    required this.child,
    required this.onEndGameFinal,
    required this.onPlayAgain,
    required this.onResumeFromSecondLife,
    this.onBackToGames,
    this.stayOnScreenAfterFinal = false,
  });

  final SecondLifeConfig config;
  final SecondLifeSession session;
  final int score;
  final int bestScore;
  final Widget child;
  final Future<void> Function() onEndGameFinal;
  final VoidCallback onPlayAgain;
  final Future<void> Function() onResumeFromSecondLife;
  final VoidCallback? onBackToGames;
  final bool stayOnScreenAfterFinal;

  @override
  State<GameSecondLifeLayer> createState() => _GameSecondLifeLayerState();
}

class _GameSecondLifeLayerState extends State<GameSecondLifeLayer> {
  late final RewardedAdService _rewardedAdService;
  bool _isShowingAd = false;

  @override
  void initState() {
    super.initState();
    _rewardedAdService = RewardedAdService();
    unawaited(_rewardedAdService.load());
  }

  @override
  void dispose() {
    _rewardedAdService.dispose();
    super.dispose();
  }

  Future<void> _handleWatchAd() async {
    if (!widget.session.canOfferSecondLife || _isShowingAd) {
      return;
    }

    setState(() {
      _isShowingAd = true;
      widget.session.isPausedForRewardAd = true;
    });

    final result = await _rewardedAdService.show();
    if (!mounted) {
      return;
    }

    setState(() => _isShowingAd = false);
    widget.session.isPausedForRewardAd = false;

    if (result.rewardEarned) {
      widget.session.markSecondLifeUsed();
      await widget.onResumeFromSecondLife();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleEndGame() async {
    widget.session.endGameFinal();
    await widget.onEndGameFinal();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOffer =
        widget.config.enabled && widget.session.awaitingSecondLifeDecision;
    final showFinalOverlay =
        widget.stayOnScreenAfterFinal &&
        widget.config.enabled &&
        widget.session.isGameOver &&
        !widget.session.awaitingSecondLifeDecision;

    return Stack(
      children: [
        widget.child,
        if (showOffer)
          GameOverContinueOverlay(
            score: widget.score,
            bestScore: widget.bestScore,
            config: widget.config,
            secondLifeAvailable: widget.session.canOfferSecondLife,
            adReady: _rewardedAdService.isReady,
            isShowingAd: _isShowingAd,
            onWatchAd: _handleWatchAd,
            onEndGame: _handleEndGame,
            onPlayAgain: widget.onPlayAgain,
            onBackToGames:
                widget.onBackToGames ?? () => Navigator.of(context).pop(),
          ),
        if (showFinalOverlay)
          GameOverContinueOverlay(
            score: widget.score,
            bestScore: widget.bestScore,
            config: widget.config,
            secondLifeAvailable: false,
            adReady: false,
            isShowingAd: false,
            onEndGame: _handleEndGame,
            onPlayAgain: widget.onPlayAgain,
            onBackToGames:
                widget.onBackToGames ?? () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}
