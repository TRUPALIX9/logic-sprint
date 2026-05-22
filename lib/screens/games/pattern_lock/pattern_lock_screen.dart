import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/brand_palette.dart';
import '../../../core/constants/app_routes.dart';
import '../../../models/game_model.dart';
import '../../../services/app_state.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/game_status_header.dart';
import '../../../widgets/primary_button.dart';
import 'pattern_lock_controller.dart';
import 'pattern_lock_widgets.dart';

class PatternLockScreen extends StatefulWidget {
  const PatternLockScreen({super.key, required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  State<PatternLockScreen> createState() => _PatternLockScreenState();
}

class _PatternLockScreenState extends State<PatternLockScreen> {
  late final PatternLockController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _controller = PatternLockController(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'Pattern Lock',
            subtitle: widget.difficulty.title,
          ),
          backgroundColor: BrandPalette.primaryNavy,
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GameStatusHeader(
                        score: _controller.score,
                        lives: _controller.lives,
                        round: _controller.round,
                      ),
                      const SizedBox(height: 18),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                _controller.statusMessage,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (_controller.isAcceptingInput) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Pattern: ${_controller.playerPattern.map((i) => i + 1).join(' → ')}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.dotCount,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _controller.config.gridSize,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                          itemBuilder: (context, index) {
                            return PatternDotTile(
                              index: index,
                              isActive: _controller.isDotActive(index),
                              onTap: _controller.isAcceptingInput
                                  ? () => _controller.addDot(index)
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Clear',
                              isSecondary: true,
                              onPressed: _controller.isAcceptingInput
                                  ? _controller.clearPlayerPattern
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Submit',
                              onPressed:
                                  _controller.isAcceptingInput &&
                                      _controller.playerPattern.length ==
                                          _controller.targetPattern.length
                                  ? () => unawaited(_controller.submitPattern())
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
