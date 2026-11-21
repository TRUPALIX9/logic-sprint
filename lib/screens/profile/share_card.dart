import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/profile_stats.dart';
import '../../models/sprint_level.dart';
import '../../ui/brand.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import '../../ui/sprint_gauge.dart';
import 'stat_text.dart';

/// The image that gets shared: LOGICSPRINT, name + code, the Sprint Score
/// gauge (or "My bests"), every game in a two-column grid and the download link. One 9:16 shape fits
/// every place it goes (Stories, Snapchat, WhatsApp, messages). Drawn
/// off-screen at [size] × [pixelRatio]; never contains ads.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.stats});

  final ProfileStats stats;

  /// Layout size in logical pixels.
  static const size = Size(360, 640);

  /// 360 × 3 = 1080 px wide.
  static const pixelRatio = 3.0;

  /// 1080 × 1920.
  static Size get pixelSize => size * pixelRatio;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: ColoredBox(
        color: LS.bg,
        child: CustomPaint(
          painter: const _GridPainter(),
          child: Padding(padding: const EdgeInsets.all(26), child: _story()),
        ),
      ),
    );
  }

  Widget _story() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Wordmark(size: 22),
      const SizedBox(height: 24),
      if (stats.name != null) ...[
        NameWithTag(name: stats.name!, tag: stats.tag, size: 26),
        const SizedBox(height: 14),
      ],
      _Headline(top: stats.sprintTop),
      const SizedBox(height: 18),
      _GameGrid(games: stats.games),
      const Spacer(),
      const _Footer(size: 24),
    ],
  );
}

/// A small static Sprint Score gauge ("TOP 7%"), or "My bests" while the
/// rank is hidden (no score yet): no rank on the image then.
class _Headline extends StatelessWidget {
  const _Headline({required this.top});

  final int? top;

  @override
  Widget build(BuildContext context) {
    final top = this.top;
    if (top == null || !SprintLevel(top).ranked) {
      return const DisplayText('My bests', size: 48);
    }
    return SprintGauge(top: top, diameter: 150, animate: false);
  }
}

/// Every game, two per row in [GameId] order (the Home grid's order), so
/// six games fit the 9:16 card with room to spare.
class _GameGrid extends StatelessWidget {
  const _GameGrid({required this.games});

  final List<GameStat> games;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < games.length; i += 2) ...[
          if (i > 0) const SizedBox(height: _gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _GameCell(stat: games[i])),
                const SizedBox(width: _gap),
                Expanded(
                  child: i + 1 < games.length
                      ? _GameCell(stat: games[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One game: title, best in its accent, then difficulty, rank and time.
class _GameCell extends StatelessWidget {
  const _GameCell({required this.stat});

  final GameStat stat;

  @override
  Widget build(BuildContext context) {
    final game = stat.game;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(color: game.accent, child: const SizedBox(width: 3)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DisplayText(game.title, size: 16, maxLines: 1),
                  const SizedBox(height: 2),
                  BestText(stat: stat, size: 24),
                  const SizedBox(height: 3),
                  // Play counts are hidden for now.
                  Text(
                    gameMeta(stat),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LSText.mono(10, spacing: 0.04),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: LS.line),
        SizedBox(height: size * 0.5),
        DisplayText('Can you beat it?', size: size),
        SizedBox(height: size * 0.25),
        Text(
          AppConfig.shareHost,
          style: LSText.mono(
            size * 0.52,
            weight: FontWeight.w700,
            spacing: 0.02,
            color: LS.teal,
          ),
        ),
      ],
    );
  }
}

/// Faint 22 px circuit grid behind the card.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LS.trace
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// Chamfered surface for the image. Plain paint (no [Material]/ink), since
/// the card is built in a private tree with no Material ancestors.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(shape: chamfer(Cut.sm), color: LS.surface),
    child: ClipPath(
      clipper: ShapeBorderClipper(shape: chamfer(Cut.sm)),
      child: child,
    ),
  );
}
