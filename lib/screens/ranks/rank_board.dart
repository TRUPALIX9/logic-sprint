import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard.dart';
import '../../ui/chamfer.dart';
import '../../ui/kit.dart';
import 'confetti.dart';
import 'rank_row.dart';

/// The Top 10 of one [LeaderboardLoad].
///
/// When the load is [LeaderboardLoad.changed], it plays once from initState
/// (so give each load its own key, e.g. `ObjectKey(load)`):
/// * first look at a board: rows drop in, staggered, no chips;
/// * otherwise every row slides from its old slot to its new one (fixed
///   56 + 6 px slots in a Stack), staggered by new position; entrants drop
///   in; scores and ranks count from old to new; chips fade in;
/// * if the player climbed, a banner slides in with their rank ticking from
///   old to new and a heavy haptic; entering the Top 10 or reaching #1 adds
///   a confetti burst.
///
/// One controller drives all rows (each maps it through its own [Interval]),
/// so only rows rebuild per frame, and only while it runs. Cached loads and
/// [reduceMotion] show the final state (chips included) without motion.
class RankBoard extends StatefulWidget {
  const RankBoard({
    super.key,
    required this.load,
    required this.me,
    required this.timed,
    required this.now,
    this.reduceMotion = false,
    this.haptics = true,
  });

  final LeaderboardLoad load;

  /// The player's id, for "YOU".
  final String? me;

  /// Show run times (games that track time).
  final bool timed;

  /// For the date lines.
  final DateTime now;
  final bool reduceMotion;
  final bool haptics;

  static const rowGap = 6.0;
  static const rowExtent = RankRow.height + rowGap;

  @override
  State<RankBoard> createState() => _RankBoardState();
}

/// The player moved up (or onto the board) in a changed load.
class _Climb {
  const _Climb(this.from, this.to);

  final int? from;
  final int to;

  static _Climb? of(LeaderboardLoad load) {
    final to = load.myRank;
    final from = load.previousMyRank;
    if (!load.changed || load.previous == null || to == null) {
      return null;
    }
    return from == null || to < from ? _Climb(from, to) : null;
  }

  /// Entered the Top 10, or reached #1.
  bool get celebrate {
    final from = this.from;
    return (to <= 10 && (from == null || from > 10)) || (to == 1 && from != 1);
  }

  String get headline {
    final from = this.from;
    if (from == null) {
      return 'You’re on the board';
    }
    final places = from - to;
    return 'You climbed $places ${places == 1 ? 'place' : 'places'}';
  }

  String? get detail {
    final from = this.from;
    return switch (from) {
      null => null,
      _ when to == 1 => 'Was #$from · Top of the board',
      _ when to <= 10 && from > 10 => 'Was #$from · Into the Top 10',
      _ => 'Was #$from',
    };
  }
}

class _RankBoardState extends State<RankBoard> with TickerProviderStateMixin {
  static const _bannerSlide = Duration(milliseconds: 350);
  static const _bannerHold = Duration(seconds: 4);

  late final AnimationController _rows;
  AnimationController? _banner;
  late final Animation<double> _bannerVisible;
  late final Map<String, RankMove> _moves;
  late final _Climb? _climb;
  late final List<int> _paintOrder;

  LeaderboardLoad get _load => widget.load;
  bool get _firstView => _load.previous == null;

  @override
  void initState() {
    super.initState();
    final count = _load.entries.length;
    _moves = _load.moves;
    _paintOrder = _order();
    _rows = AnimationController(
      vsync: this,
      duration:
          AppConfig.leaderboardRowMove +
          AppConfig.leaderboardRowStagger * math.max(count - 1, 0),
    );
    if (_load.changed && !widget.reduceMotion) {
      _rows.forward();
    } else {
      _rows.value = 1;
    }

    _climb = _Climb.of(_load);
    final banner = _banner = _climb == null
        ? null
        : AnimationController(
            vsync: this,
            duration: _bannerSlide * 2 + _bannerHold,
          );
    final slide = _bannerSlide.inMilliseconds.toDouble();
    _bannerVisible = banner == null
        ? kAlwaysDismissedAnimation
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(
                begin: 0.0,
                end: 1.0,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
              weight: slide,
            ),
            TweenSequenceItem(
              tween: ConstantTween(1.0),
              weight: _bannerHold.inMilliseconds.toDouble(),
            ),
            TweenSequenceItem(
              tween: Tween(
                begin: 1.0,
                end: 0.0,
              ).chain(CurveTween(curve: Curves.easeInCubic)),
              weight: slide,
            ),
          ]).animate(banner);
    if (banner != null) {
      if (widget.reduceMotion) {
        banner.value = 0.5; // Mid-hold: shown, and it stays.
      } else {
        banner.forward();
      }
      if (widget.haptics) {
        HapticFeedback.heavyImpact();
      }
    }
  }

  /// Stack paint order: movers above the rows they pass, the player on top.
  List<int> _order() {
    final entries = _load.entries;
    int weight(int i) {
      final e = entries[i];
      if (widget.me != null && e.playerId == widget.me) {
        return 1000;
      }
      final move = _moves[e.playerId];
      return switch (move?.kind) {
        RankMoveKind.up => 100 + move!.places,
        RankMoveKind.entered => 90,
        RankMoveKind.down => 10,
        _ => 0,
      };
    }

    return List.generate(entries.length, (i) => i)
      ..sort((a, b) => weight(a).compareTo(weight(b)));
  }

  @override
  void dispose() {
    _rows.dispose();
    _banner?.dispose();
    super.dispose();
  }

  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

  String? _detail(int i, LeaderboardEntry entry) {
    final at = entry.bestAt;
    if (at == null) {
      return null;
    }
    return i == 0
        ? '#1 since ${formatSince(at, now: widget.now)}'
        : formatWhen(at, now: widget.now);
  }

  Widget _row(int i) {
    final entry = _load.entries[i];
    final isYou = widget.me != null && entry.playerId == widget.me;
    final move = _firstView ? null : _moves[entry.playerId];
    final from = move?.from;
    final dropIn = from == null;
    final fromScore = from == null ? entry.score : _load.previous![from].score;
    final previousMyRank = _load.previousMyRank;
    final fromRank = from != null
        ? from + 1
        : (isYou && !_firstView && previousMyRank != null
              ? previousMyRank
              : i + 1);
    final total = _rows.duration!.inMilliseconds;
    final start = AppConfig.leaderboardRowStagger.inMilliseconds * i;
    final interval = Interval(
      start / total,
      math.min(
        1,
        (start + AppConfig.leaderboardRowMove.inMilliseconds) / total,
      ),
      curve: Curves.easeOutCubic,
    );
    final detail = _detail(i, entry);
    final time = widget.timed ? entry.duration : null;

    return AnimatedBuilder(
      animation: _rows,
      builder: (context, _) {
        final t = interval.transform(_rows.value);
        final top = dropIn
            ? i * RankBoard.rowExtent - (1 - t) * 18
            : (from + (i - from) * t) * RankBoard.rowExtent;
        final row = RankRow(
          rank: _lerpInt(fromRank, i + 1, t),
          name: entry.playerName,
          score: _lerpInt(fromScore, entry.score, t),
          time: time,
          isYou: isYou,
          detail: detail,
          move: move,
          chipOpacity: t,
        );
        return Positioned(
          left: 0,
          right: 0,
          top: top,
          height: RankRow.height,
          child: t < 1 && dropIn ? Opacity(opacity: t, child: row) : row,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _load.entries.length;
    final climb = _climb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (climb != null)
          _ClimbBanner(
            climb: climb,
            visible: _bannerVisible,
            reduceMotion: widget.reduceMotion,
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    height: count * RankBoard.rowExtent - RankBoard.rowGap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [for (final i in _paintOrder) _row(i)],
                    ),
                  ),
                ),
              ),
              if (climb != null && climb.celebrate && !widget.reduceMotion)
                const Positioned.fill(
                  child: ConfettiBurst(origin: Alignment(0, -0.9)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClimbBanner extends StatelessWidget {
  const _ClimbBanner({
    required this.climb,
    required this.visible,
    required this.reduceMotion,
  });

  final _Climb climb;
  final Animation<double> visible;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final detail = climb.detail;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: ChamferBox(
        cut: Cut.sm,
        color: LS.teal.withValues(alpha: 0.08),
        borderColor: LS.teal.withValues(alpha: 0.55),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            const Icon(Icons.trending_up_rounded, color: LS.teal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DisplayText(
                    climb.headline,
                    size: 17,
                    color: LS.teal,
                    maxLines: 1,
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    MonoLabel(detail, size: 10, color: LS.dim),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: climb.from ?? climb.to, end: climb.to),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, rank, _) => Text(
                '#$rank',
                style: LSText.mono(
                  24,
                  weight: FontWeight.w700,
                  spacing: 0,
                  color: LS.teal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: visible,
      child: content,
      builder: (context, child) {
        final v = visible.value;
        if (v <= 0) {
          return const SizedBox.shrink();
        }
        if (v >= 1) {
          return child!;
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: v,
            child: Opacity(opacity: v, child: child),
          ),
        );
      },
    );
  }
}
