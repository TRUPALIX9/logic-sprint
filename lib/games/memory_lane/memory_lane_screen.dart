import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/game.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import '../round_screen.dart';
import 'memory_lane_engine.dart';

class MemoryLaneScreen extends StatelessWidget {
  const MemoryLaneScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final n = MemoryLaneEngine.gridSizeFor(difficulty);
    return RoundScreen<MemoryLaneEngine>(
      game: GameId.memoryLane,
      difficulty: difficulty,
      subtitle: '${difficulty.label} · $n×$n',
      createEngine: (feedback, best) => MemoryLaneEngine(
        difficulty: difficulty,
        previousBest: best,
        feedback: feedback,
      ),
      builder: (context, engine) => _MemoryLaneBody(engine),
    );
  }
}

class _MemoryLaneBody extends StatelessWidget {
  const _MemoryLaneBody(this.engine);

  final MemoryLaneEngine engine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusStrip(engine),
          const SizedBox(height: 16),
          MonoLabel(
            'Level ${engine.level}',
            size: 12,
            color: LS.aqua,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 16),
          // Fills the rest of the screen; tiles stretch taller on tall phones.
          Expanded(
            child: ChamferBox(
              cut: Cut.lg,
              color: LS.well,
              padding: const EdgeInsets.all(16),
              child: _Grid(engine),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip(this.engine);

  final MemoryLaneEngine engine;

  @override
  Widget build(BuildContext context) {
    final watching = engine.phase == MemoryPhase.watch;
    final accent = watching ? LS.aqua : LS.teal;
    return ChamferBox(
      color: accent.withValues(alpha: watching ? 0.1 : 0.06),
      borderColor: watching ? null : LS.teal.withValues(alpha: 0.33),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DisplayText(
              watching ? 'Watch the pattern' : 'Repeat the pattern',
              size: 19,
              color: accent,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          // Taps done / tiles to repeat; 0/Y dimmed while watching.
          Text(
            '${watching ? 0 : engine.stepsDone}/${engine.sequenceLength}',
            style: LSText.mono(
              15,
              color: watching ? LS.dim : LS.teal,
              weight: FontWeight.w700,
              spacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid(this.engine);

  final MemoryLaneEngine engine;

  @override
  Widget build(BuildContext context) {
    final n = engine.gridSize;
    return Column(
      spacing: 10,
      children: [
        for (var row = 0; row < n; row++)
          Expanded(
            child: Row(
              spacing: 10,
              children: [
                for (var col = 0; col < n; col++)
                  Expanded(
                    child: _Tile(engine: engine, index: row * n + col),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.engine, required this.index});

  final MemoryLaneEngine engine;
  final int index;

  @override
  Widget build(BuildContext context) {
    final lit = engine.litTile == index;
    final Color? state = engine.wrongTile == index
        ? LS.coral
        : engine.correctTile == index
        ? LS.teal
        : null;
    final tile = ChamferBox(
      cut: Cut.sm,
      borderColor: null,
      color: lit ? LS.aqua : state?.withValues(alpha: 0.15) ?? LS.surface2,
      onTap: engine.canTap ? () => engine.tap(index) : null,
      child: Center(
        child: lit
            ? const SizedBox.square(
                dimension: 10,
                child: ColoredBox(color: LS.bg),
              )
            : SizedBox.square(
                dimension: state == null ? 6 : 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state ?? LS.line,
                  ),
                ),
              ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Tile ${index + 1}',
      // The glow sits outside the tile's clip so it can bleed past the cut.
      child: lit
          ? DecoratedBox(
              decoration: ShapeDecoration(
                shape: chamfer(Cut.sm),
                shadows: [
                  BoxShadow(
                    color: LS.aqua.withValues(alpha: 0.7),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: tile,
            )
          : tile,
    );
  }
}
