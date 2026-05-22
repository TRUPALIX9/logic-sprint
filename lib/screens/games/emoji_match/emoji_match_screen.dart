import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../models/game_model.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/game_status_header.dart';
import '../../../widgets/timer_bar.dart';
import 'emoji_match_controller.dart';
import 'emoji_match_widgets.dart';

class EmojiMatchScreen extends StatefulWidget {
  const EmojiMatchScreen({super.key, required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  State<EmojiMatchScreen> createState() => _EmojiMatchScreenState();
}

class _EmojiMatchScreenState extends State<EmojiMatchScreen> {
  late final EmojiMatchController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = EmojiMatchController(
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
      _controller.gameType,
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

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _controller.config.totalTime.inSeconds;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'Emoji Match',
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
                        progress: totalSeconds == 0
                            ? 0
                            : _controller.remainingSeconds / totalSeconds,
                        secondsRemaining: _controller.remainingSeconds,
                      ),
                      const SizedBox(height: 18),
                      GameStatusHeader(
                        score: _controller.score,
                        remainingSeconds: _controller.remainingSeconds,
                        matches:
                            '${_controller.matchedPairCount}/${_controller.config.pairCount}',
                      ),
                      const SizedBox(height: 18),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _controller.statusMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _controller.cards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _controller.config.crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemBuilder: (context, index) {
                          return EmojiCardTile(
                            card: _controller.cards[index],
                            onTap: _controller.isCheckingPair
                                ? null
                                : () => unawaited(
                                    _controller.handleCardTap(index),
                                  ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
