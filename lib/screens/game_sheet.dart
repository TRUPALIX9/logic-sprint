import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../games/games.dart';
import '../models/game.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/kit.dart';

Future<void> showGameSheet(BuildContext context, GameId game) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GameSheet(game: game),
    );

/// Rules + difficulty picker; replaces the old Game Select and Difficulty screens.
class GameSheet extends StatefulWidget {
  const GameSheet({super.key, required this.game});

  final GameId game;

  @override
  State<GameSheet> createState() => _GameSheetState();
}

class _GameSheetState extends State<GameSheet> {
  late Difficulty _difficulty;

  @override
  void initState() {
    super.initState();
    final last = context.read<AppState>().lastPlayed;
    _difficulty = last != null && last.$1 == widget.game
        ? last.$2
        : Difficulty.easy;
  }

  void _start() {
    final navigator = Navigator.of(context);
    navigator
      ..pop()
      ..push(
        gameRoute(
          widget.game,
          widget.game.hasDifficulty ? _difficulty : GameId.rampDifficulty,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final game = widget.game;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: chamfer(Cut.lg, border: LS.line),
        color: LS.surface,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, color: LS.line)),
              const SizedBox(height: 18),
              Row(
                children: [
                  GameTile(game: game, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DisplayText(game.title, size: 28, maxLines: 1),
                        const SizedBox(height: 5),
                        MonoLabel(game.skill, color: game.accent),
                      ],
                    ),
                  ),
                  LSIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    color: LS.muted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(game.rules, style: LSText.body(15, color: LS.muted)),
              const SizedBox(height: 18),
              if (game.hasDifficulty) ...[
                const MonoLabel('Difficulty', size: 12),
                const SizedBox(height: 10),
                for (final difficulty in Difficulty.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DifficultyOption(
                      game: game,
                      difficulty: difficulty,
                      best: app.best(game, difficulty),
                      selected: difficulty == _difficulty,
                      onTap: () => setState(() => _difficulty = difficulty),
                    ),
                  ),
              ] else
                _RampNote(
                  game: game,
                  best: app.best(game, GameId.rampDifficulty),
                ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Start',
                icon: Icons.play_arrow_rounded,
                accent: game.accent,
                onPressed: _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stands in for the difficulty picker on games that ramp up instead.
class _RampNote extends StatelessWidget {
  const _RampNote({required this.game, required this.best});

  final GameId game;
  final int best;

  @override
  Widget build(BuildContext context) {
    return ChamferBox(
      height: 64,
      color: LS.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: game.accent),
          const SizedBox(width: 14),
          Expanded(child: DisplayText(game.rampNote ?? '', size: 18)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const MonoLabel('Best', size: 10, color: LS.dim),
              const SizedBox(height: 3),
              Text(
                best > 0 ? '$best' : '—',
                style: LSText.mono(
                  16,
                  weight: FontWeight.w700,
                  spacing: 0,
                  color: game.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.game,
    required this.difficulty,
    required this.best,
    required this.selected,
    required this.onTap,
  });

  final GameId game;
  final Difficulty difficulty;
  final int best;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = game.accent;
    return Semantics(
      selected: selected,
      child: ChamferBox(
        height: 64,
        color: selected ? accent.withValues(alpha: 0.08) : LS.surface2,
        borderColor: selected ? accent : LS.line,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: selected ? accent : LS.dim, width: 2),
              ),
              child: selected
                  ? Container(width: 10, height: 10, color: accent)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DisplayText(difficulty.label, size: 19),
                  const SizedBox(height: 3),
                  MonoLabel(game.detail(difficulty)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const MonoLabel('Best', size: 10, color: LS.dim),
                const SizedBox(height: 3),
                Text(
                  best > 0 ? '$best' : '—',
                  style: LSText.mono(
                    16,
                    weight: FontWeight.w700,
                    spacing: 0,
                    color: selected ? accent : LS.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
