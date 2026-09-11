import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/game.dart';
import '../screens/result_screen.dart';
import '../services/ads.dart';
import '../state/app_state.dart';
import '../ui/game_bar.dart';
import 'round_engine.dart';

/// Hosts one round: builds the engine, starts it after the first frame,
/// shows the game bar, and on finish saves the best, runs the between-round
/// ad, then replaces itself with the Result screen.
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
  late final T _engine;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _engine = widget.createEngine(app, app.best(widget.game, widget.difficulty))
      ..addListener(_onEngineChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _engine.start();
      }
    });
  }

  Future<void> _onEngineChange() async {
    final result = _engine.result;
    if (result == null || _handled) {
      return;
    }
    _handled = true;
    final ads = context.read<Ads>();
    await context.read<AppState>().recordRound(result);
    if (!mounted) {
      return;
    }
    ads.afterRound(() {
      if (mounted) {
        Navigator.of(context).pushReplacement(resultRoute(result));
      }
    });
  }

  @override
  void dispose() {
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
          builder: (context, _) => Column(
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
        ),
      ),
    );
  }
}
