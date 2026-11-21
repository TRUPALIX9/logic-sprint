import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../screens/result_screen.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/network.dart';
import '../state/app_state.dart';
import '../ui/chamfer.dart';
import '../ui/game_bar.dart';
import '../ui/kit.dart';
import 'round_engine.dart';

/// Whether a run that just went down is worth a revive offer: online
/// (offline play is ad-free, so no revives at all), revives left, a score of
/// at least [AppConfig.reviveMinScore], and a way to pay (a heart or a
/// loaded rewarded ad).
bool offersRevive(
  RoundEngine engine, {
  required bool online,
  required int hearts,
  required bool adReady,
}) =>
    online &&
    engine.canRevive &&
    engine.score >= AppConfig.reviveMinScore &&
    (hearts > 0 || adReady);

/// Hosts one endless run: builds the engine, starts it after the first frame,
/// shows the game bar, pauses when the app leaves the foreground (or on the
/// pause button or the phone's back button), offers a revive (heart or rewarded ad) when the run goes
/// down, then saves the best and replaces itself with the Result screen.
class RoundScreen<T extends RoundEngine> extends StatefulWidget {
  const RoundScreen({
    super.key,
    required this.game,
    required this.difficulty,
    required this.createEngine,
    required this.builder,
  });

  final GameId game;
  final Difficulty difficulty;
  final T Function(RoundFeedback feedback, int previousBest) createEngine;
  final Widget Function(BuildContext context, T engine) builder;

  @override
  State<RoundScreen<T>> createState() => _RoundScreenState<T>();
}

class _RoundScreenState<T extends RoundEngine> extends State<RoundScreen<T>> {
  /// How long the failure shows before the run ends when there's no revive.
  static const _endDelay = Duration(milliseconds: 700);

  late final T _engine;
  late final Ads _ads;
  late final Network _network;
  late final AppLifecycleListener _lifecycle;
  Timer? _endTimer;

  /// Decided once each time the run goes down.
  bool _offering = false;

  /// A heart is being spent or the rewarded ad is showing.
  bool _reviving = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _ads = context.read<Ads>()..preloadRewarded();
    _network = context.read<Network>()..online.addListener(_onNetworkChange);
    _engine = widget.createEngine(app, app.best(widget.game, widget.difficulty))
      ..addListener(_onEngineChange);
    // Inactive, hidden or paused: hold the run until the player taps Resume.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) {
          _engine.pause();
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _engine.start();
      }
    });
  }

  // Runs before the AnimatedBuilder's listener, so [_offering] is set by the
  // time the overlay rebuilds.
  void _onEngineChange() {
    switch (_engine.state) {
      case RunState.down:
        if (_offering || _endTimer != null) {
          return;
        }
        final hearts = context.read<AppState>().hearts;
        if (offersRevive(
          _engine,
          online: _network.online.value,
          hearts: hearts,
          adReady: _ads.rewardedReady.value,
        )) {
          _offering = true;
        } else {
          _endTimer = Timer(_endDelay, _engine.finish);
        }
      case RunState.over:
        _offering = false;
        _reviving = false;
        _showResult();
      case RunState.ready ||
          RunState.playing ||
          RunState.paused ||
          RunState.resuming:
        _offering = false;
        _reviving = false;
        _endTimer?.cancel();
        _endTimer = null;
    }
  }

  /// Offline play is ad-free: losing the connection while the revive offer
  /// is up ends the run (unless a revive is already under way).
  void _onNetworkChange() {
    if (!_network.online.value &&
        _offering &&
        !_reviving &&
        _engine.state == RunState.down) {
      _engine.finish();
    }
  }

  Future<void> _showResult() async {
    final result = _engine.result;
    if (result == null || _handled) {
      return;
    }
    _handled = true;
    // History + server sync run in the background; Result shows the outcome.
    final synced = context.read<Leaderboard>().recordRun(result);
    await context.read<AppState>().recordRound(result);
    if (!mounted) {
      return;
    }
    if (_leaveHome) {
      // Back while paused or down: the run is saved, then straight home.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushReplacement(resultRoute(result, synced: synced));
  }

  /// Set when the phone's back button ends the run; skips the Result screen.
  bool _leaveHome = false;

  /// Back while playing pauses (a stray swipe never throws a run away);
  /// back again, while paused, down or counting in, saves the run and goes
  /// home.
  void _onBack() {
    // A heart or ad revive is settling: ending now could spend the heart
    // and still end the run.
    if (_reviving) {
      return;
    }
    switch (_engine.state) {
      case RunState.playing:
        _engine.pause();
      case RunState.paused || RunState.down || RunState.resuming:
        _leaveHome = true;
        _endTimer?.cancel();
        _engine.finish();
      case RunState.ready:
        Navigator.of(context).pop();
      case RunState.over:
        break;
    }
  }

  Future<void> _useHeart() async {
    _reviving = true;
    final spent = await context.read<AppState>().useHeart();
    if (spent) {
      _engine.revive(hold: true);
    } else {
      _engine.finish();
    }
  }

  /// The reward settles after the ad is dismissed (see RewardOutcome), so
  /// the get-ready countdown starts on the game screen, not behind the ad.
  void _watchAd() {
    _reviving = true;
    _ads.showRewarded(
      onReward: () => _engine.revive(hold: true),
      onDone: _engine.finish,
    );
  }

  @override
  void dispose() {
    _network.online.removeListener(_onNetworkChange);
    _lifecycle.dispose();
    _endTimer?.cancel();
    _engine
      ..removeListener(_onEngineChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hearts = context.select<AppState, int>((app) => app.hearts);
    // Back pauses a live run; back again (paused or down) saves it and goes
    // home. End run on the paused card still shows the Result screen.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Scaffold(
        backgroundColor: LS.bg,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _engine,
            // The bar stays above the overlays so Back and Resume work while
            // paused.
            builder: (context, _) => Column(
              children: [
                GameBar(
                  game: widget.game,
                  score: _engine.score,
                  paused: _engine.isPaused,
                  onPause: _engine.isPlaying ? _engine.pause : null,
                  onResume: _engine.resume,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.builder(context, _engine)),
                      if (_engine.isResuming)
                        GetReady(
                          // A fresh countdown for every revive.
                          key: ValueKey(_engine.revives),
                          color: widget.game.accent,
                          onGo: _engine.go,
                        ),
                      if (_engine.isPaused)
                        _PausedOverlay(
                          score: _engine.score,
                          onResume: _engine.resume,
                          onEnd: _engine.finish,
                        ),
                      if (_offering && _engine.state == RunState.down)
                        ValueListenableBuilder<bool>(
                          valueListenable: _ads.rewardedReady,
                          builder: (context, adReady, _) => ReviveOffer(
                            // A fresh offer (and countdown) for every down.
                            key: ValueKey(_engine.revives),
                            score: _engine.score,
                            revives: _engine.revives,
                            hearts: hearts,
                            adReady: adReady,
                            onHeart: _useHeart,
                            onWatch: _watchAd,
                            onEnd: _engine.finish,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The get-ready countdown after a revive: 3 · 2 · 1 in the game's accent
/// over a dark scrim that fades out slowly, then [onGo]. Touches pass through
/// (Rocket Launch can line up the ship). Leaving the app holds it; coming
/// back starts it again from 3. Reduce motion drops the digit's scale-in but
/// never shortens the countdown.
class GetReady extends StatefulWidget {
  const GetReady({super.key, required this.color, required this.onGo});

  static const duration = Duration(seconds: 3);

  /// Scrim opacity at the start; it fades to 0 by the end.
  static const startOpacity = 0.85;

  final Color color;
  final VoidCallback onGo;

  @override
  State<GetReady> createState() => _GetReadyState();
}

class _GetReadyState extends State<GetReady>
    with SingleTickerProviderStateMixin {
  // Preserve: reduce motion must not skip the countdown.
  late final _clock =
      AnimationController(
          vsync: this,
          duration: GetReady.duration,
          animationBehavior: AnimationBehavior.preserve,
        )
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);
  late final AppLifecycleListener _lifecycle;
  late final AppState _app = context.read<AppState>();
  int _shown = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (_done) {
          return;
        }
        if (state == AppLifecycleState.resumed) {
          _clock.forward(from: 0);
        } else {
          _clock
            ..stop()
            ..value = 0;
        }
      },
    );
    _clock.forward();
  }

  /// A haptic tick (and click, if sounds are on) as each number appears.
  void _onTick() {
    final digit = _digit(_clock.value);
    if (digit != _shown) {
      _shown = digit;
      _app.tap();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_done) {
      _done = true;
      widget.onGo();
    }
  }

  /// 3, 2, 1 across the countdown.
  int _digit(double t) => (3 - (t * 3).floor()).clamp(1, 3);

  @override
  void dispose() {
    _lifecycle.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value;
            final digit = _digit(t);
            // Progress through the current second, 0 → 1.
            final inSecond = (t * 3) - (t * 3).floor();
            final pop = Curves.easeOutCubic.transform(
              (inSecond / 0.3).clamp(0.0, 1.0),
            );
            final fade = math.pow(1 - t, 1.6).toDouble();
            return ColoredBox(
              color: Colors.black.withValues(
                alpha: GetReady.startOpacity * fade,
              ),
              child: Semantics(
                liveRegion: true,
                label: 'Get ready, $digit',
                excludeSemantics: true,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: calm ? 1 : pop,
                        child: Transform.scale(
                          scale: calm ? 1 : 1.5 - 0.5 * pop,
                          child: Text(
                            '$digit',
                            style: LSText.mono(
                              120,
                              color: widget.color,
                              weight: FontWeight.w700,
                              spacing: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const MonoLabel('Get ready', color: LS.text),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dark scrim with a chamfered card in the middle.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: const EdgeInsets.all(24),
      child: ChamferBox(
        cut: Cut.lg,
        borderColor: LS.teal.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xD9000000),
        child: Center(child: SingleChildScrollView(child: card)),
      ),
    );
  }
}

/// The run on hold (app backgrounded or the pause button). Only Resume (here
/// or in the bar) continues it; returning to the app doesn't.
class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({
    required this.score,
    required this.onResume,
    required this.onEnd,
  });

  final int score;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.pause_circle_outline_rounded,
            color: LS.teal,
            size: 40,
          ),
          const SizedBox(height: 12),
          const DisplayText('Paused', size: 30, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Center(child: MonoLabel('Score $score')),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            onPressed: onResume,
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'End run', onPressed: onEnd),
        ],
      ),
    );
  }
}

/// "Game over — one more life?": spend a heart or watch a rewarded ad. It
/// auto-declines (calls [onEnd]) after [AppConfig.reviveOfferSeconds]; any
/// button stops the countdown.
class ReviveOffer extends StatefulWidget {
  const ReviveOffer({
    super.key,
    required this.score,
    required this.revives,
    required this.hearts,
    required this.adReady,
    required this.onHeart,
    required this.onWatch,
    required this.onEnd,
  });

  final int score;

  /// Revives used so far this run.
  final int revives;
  final int hearts;
  final bool adReady;
  final VoidCallback onHeart;
  final VoidCallback onWatch;

  /// End run, also called when the countdown runs out.
  final VoidCallback onEnd;

  @override
  State<ReviveOffer> createState() => _ReviveOfferState();
}

class _ReviveOfferState extends State<ReviveOffer>
    with SingleTickerProviderStateMixin {
  static const _window = Duration(seconds: AppConfig.reviveOfferSeconds);

  // Preserve: reduce-motion must not shorten the countdown; the ring is
  // simply not animated then.
  late final _ring = AnimationController(
    vsync: this,
    duration: _window,
    animationBehavior: AnimationBehavior.preserve,
  );
  Timer? _timeout;
  Timer? _second;
  int _secondsLeft = AppConfig.reviveOfferSeconds;
  bool _calm = false;
  late final AppLifecycleListener _lifecycle;

  /// A button was pressed (or time ran out): the countdown is over.
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    // Leaving the app holds the offer; coming back restarts the full window,
    // so a run never ends while the app is in the background.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          state == AppLifecycleState.resumed ? _restart() : _hold(),
    );
    _startTimers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    if (_calm) {
      _ring.stop();
    } else if (!_decided && !_ring.isAnimating && _timeout != null) {
      _ring.forward();
    }
  }

  void _startTimers() {
    _timeout = Timer(_window, () => _decide(widget.onEnd));
    _second = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _hold() {
    _timeout?.cancel();
    _second?.cancel();
    _timeout = null;
    _second = null;
    _ring.stop();
  }

  void _restart() {
    if (_decided || !mounted) {
      return;
    }
    _hold();
    setState(() => _secondsLeft = AppConfig.reviveOfferSeconds);
    _ring.value = 0;
    if (!_calm) {
      _ring.forward();
    }
    _startTimers();
  }

  void _decide(VoidCallback action) {
    if (_decided) {
      return;
    }
    setState(() => _decided = true);
    _hold();
    action();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _hold();
    _ring.dispose();
    super.dispose();
  }

  VoidCallback? _button(VoidCallback action) =>
      _decided ? null : () => _decide(action);

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    final withHeart = widget.hearts > 0;
    return _Scrim(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _CountdownRing(
              ring: _ring,
              seconds: _secondsLeft,
              animate: !calm,
            ),
          ),
          const SizedBox(height: 12),
          const DisplayText('Game over', size: 30, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Center(child: MonoLabel('Score ${widget.score}')),
          if (widget.revives > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: MonoLabel(
                'Revived ${widget.revives}/${AppConfig.maxRevivesPerRun}',
                size: 10,
                color: LS.dim,
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (withHeart) ...[
            PrimaryButton(
              label: 'Use ❤ · ${widget.hearts} left',
              icon: Icons.favorite_rounded,
              onPressed: _button(widget.onHeart),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.adReady) ...[
            if (withHeart)
              SecondaryButton(
                label: 'Watch ad · +1 life',
                icon: Icons.play_circle_outline_rounded,
                onPressed: _button(widget.onWatch),
              )
            else
              PrimaryButton(
                label: 'Watch ad · +1 life',
                icon: Icons.play_circle_outline_rounded,
                onPressed: _button(widget.onWatch),
              ),
            const SizedBox(height: 10),
          ],
          SecondaryButton(label: 'End run', onPressed: _button(widget.onEnd)),
        ],
      ),
    );
  }
}

/// Seconds left inside a ring that drains with [ring] (static when
/// [animate] is false, e.g. reduce motion).
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.ring,
    required this.seconds,
    required this.animate,
  });

  final Animation<double> ring;
  final int seconds;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Offer ends in $seconds seconds',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (animate)
              AnimatedBuilder(
                animation: ring,
                builder: (context, _) => CircularProgressIndicator(
                  value: 1 - ring.value,
                  strokeWidth: 3,
                  color: LS.coral,
                  backgroundColor: LS.surface2,
                ),
              )
            else
              const CircularProgressIndicator(
                value: 1,
                strokeWidth: 3,
                color: LS.surface2,
              ),
            Center(
              child: Text(
                '$seconds',
                style: LSText.mono(20, color: LS.text, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
