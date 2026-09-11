import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/game.dart';
import '../screens/result_screen.dart';
import '../services/ads.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/game_bar.dart';
import '../ui/kit.dart';
import 'round_engine.dart';

/// Hosts one endless run: builds the engine, starts it after the first frame,
/// shows the game bar, offers one rewarded-ad revive when the run goes down,
/// then saves the best and replaces itself with the Result screen.
class RoundScreen<T extends RoundEngine> extends StatefulWidget {
  const RoundScreen({
    super.key,
    required this.game,
    required this.difficulty,
    required this.createEngine,
    required this.builder,
    this.subtitle,
  });

  final GameId game;
  final Difficulty difficulty;
  final T Function(RoundFeedback feedback, int previousBest) createEngine;
  final Widget Function(BuildContext context, T engine) builder;

  /// Overrides the difficulty label under the title (e.g. "MEDIUM · 4×4").
  final String? subtitle;

  @override
  State<RoundScreen<T>> createState() => _RoundScreenState<T>();
}

class _RoundScreenState<T extends RoundEngine> extends State<RoundScreen<T>> {
  /// How long the failure shows before the run ends when there's no revive.
  static const _endDelay = Duration(milliseconds: 700);

  late final T _engine;
  late final Ads _ads;
  Timer? _endTimer;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _ads = context.read<Ads>()..preloadRewarded();
    _engine = widget.createEngine(app, app.best(widget.game, widget.difficulty))
      ..addListener(_onEngineChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _engine.start();
      }
    });
  }

  bool get _offerRevive =>
      _engine.state == RunState.down &&
      _engine.canRevive &&
      _ads.rewardedReady.value;

  void _onEngineChange() {
    switch (_engine.state) {
      case RunState.down:
        if (!_offerRevive) {
          _endTimer ??= Timer(_endDelay, _engine.finish);
        }
      case RunState.over:
        _showResult();
      case RunState.ready || RunState.playing:
        _endTimer?.cancel();
        _endTimer = null;
    }
  }

  Future<void> _showResult() async {
    final result = _engine.result;
    if (result == null || _handled) {
      return;
    }
    _handled = true;
    await context.read<AppState>().recordRound(result);
    if (mounted) {
      Navigator.of(context).pushReplacement(resultRoute(result));
    }
  }

  void _watchAd() =>
      _ads.showRewarded(onReward: _engine.revive, onDone: _engine.finish);

  @override
  void dispose() {
    _endTimer?.cancel();
    _engine
      ..removeListener(_onEngineChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LS.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _engine,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                  GameBar(
                    game: widget.game,
                    subtitle:
                        widget.subtitle ??
                        (widget.game.hasDifficulty
                            ? widget.difficulty.label
                            : widget.game.skill),
                    score: _engine.score,
                  ),
                  Expanded(child: widget.builder(context, _engine)),
                ],
              ),
              if (_offerRevive)
                _ReviveOffer(
                  score: _engine.score,
                  onWatch: _watchAd,
                  onEnd: _engine.finish,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Game over — watch an ad for one more life", shown once per run.
class _ReviveOffer extends StatelessWidget {
  const _ReviveOffer({
    required this.score,
    required this.onWatch,
    required this.onEnd,
  });

  final int score;
  final VoidCallback onWatch;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xD9000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ChamferBox(
              cut: Cut.lg,
              borderColor: LS.teal.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.favorite_rounded, color: LS.coral, size: 40),
                  const SizedBox(height: 12),
                  const DisplayText(
                    'Game over',
                    size: 30,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Center(child: MonoLabel('Score $score')),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Watch ad · +1 life',
                    icon: Icons.play_circle_outline_rounded,
                    onPressed: onWatch,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(label: 'End run', onPressed: onEnd),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
