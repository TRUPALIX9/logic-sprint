import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../models/game.dart';

/// In-game music: each game has its own quiet loop in `assets/audio/`,
/// composed for LogicSprint by `tool/compose_music.py` (original, no licence
/// needed). Rocket Launch is a continuous space ambience, Memory Lane a soft
/// piano, Quick Math a marimba, Guess Color electric-piano bells, Angle
/// Sense a music box and Line Split a kalimba.
///
/// Menus are silent. A game's track fades in while its run is live, pauses
/// while the run is paused or down (the revive offer), when the app leaves
/// the screen or while a full-screen ad plays, and fades out at game over.
///
/// The audio session is "ambient": it mixes with music from other apps,
/// follows the iPhone silent switch, and never takes audio focus on Android.
class Music with WidgetsBindingObserver {
  Music({AudioPlayer? player}) : _player = player;

  /// The app's instance, set in main(); null in tests and previews.
  static Music? current;

  static String assetFor(GameId game) => 'assets/audio/${game.name}.m4a';

  /// Quiet on purpose: it should sit under the game, not over it.
  static const volume = 0.4;
  static const _fadeIn = Duration(milliseconds: 1500);
  static const _fadeOut = Duration(milliseconds: 700);

  AudioPlayer? _player;
  bool _wanted = false;
  bool _foreground = true;
  bool _adPlaying = false;
  bool _runLive = false;
  GameId? _loaded;
  GameId? _game;
  Timer? _fade;
  int _generation = 0;
  GameId? _loadingGame;
  Future<void>? _loading;

  /// Sets up the audio session. Nothing plays until a run starts.
  Future<void> init({required bool on}) async {
    WidgetsBinding.instance.addObserver(this);
    _wanted = on;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.game,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
        ),
      );
      _player ??= AudioPlayer(
        handleAudioSessionActivation: false,
        handleInterruptions: false,
      );
    } on Object catch (e) {
      debugPrint('Music unavailable: $e');
    }
  }

  /// The player's Music setting.
  set on(bool value) {
    _wanted = value;
    unawaited(_sync());
  }

  /// A run of [game] is on screen; [live] while it is being played (not
  /// paused, not down).
  void inRun(GameId game, {required bool live}) {
    _game = game;
    _runLive = live;
    unawaited(_sync());
  }

  /// The run ended (game over) or its screen closed: fade out.
  void endRun() {
    _runLive = false;
    _game = null;
    unawaited(_sync());
  }

  /// A full-screen ad started or ended: rewarded ads play their own sound.
  void adStarted() {
    _adPlaying = true;
    unawaited(_sync());
  }

  void adEnded() {
    _adPlaying = false;
    unawaited(_sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_sync());
  }

  /// Whether a game's track should be audible right now.
  @visibleForTesting
  static bool shouldPlay({
    required bool wanted,
    required bool foreground,
    required bool adPlaying,
    required bool runLive,
  }) => wanted && foreground && !adPlaying && runLive;

  Future<void> _sync() async {
    final player = _player;
    if (player == null) {
      return;
    }
    final generation = ++_generation;
    final game = _game;
    final play =
        game != null &&
        shouldPlay(
          wanted: _wanted,
          foreground: _foreground,
          adPlaying: _adPlaying,
          runLive: _runLive,
        );
    if (!play) {
      if (player.playing) {
        _fadeTo(player, 0, _fadeOut, then: player.pause);
      }
      return;
    }
    if (!await _ensureLoaded(player, game)) {
      return;
    }
    // Something changed while the track was loading: that call decides.
    if (generation != _generation) {
      return;
    }
    if (!player.playing) {
      unawaited(player.setVolume(0));
      unawaited(player.play());
      assert(() {
        debugPrint('Music: playing ${game.name}');
        return true;
      }());
    }
    _fadeTo(player, volume, _fadeIn);
  }

  /// Loads [game]'s track once. A second call for the same game while it is
  /// loading waits for that load instead of starting (and interrupting)
  /// another one.
  Future<bool> _ensureLoaded(AudioPlayer player, GameId game) async {
    if (_loaded == game) {
      return true;
    }
    if (_loadingGame != game || _loading == null) {
      _loadingGame = game;
      _loading = () async {
        _fade?.cancel();
        await player.setAsset(assetFor(game));
        await player.setLoopMode(LoopMode.one);
        _loaded = game;
      }();
    }
    try {
      await _loading;
    } on Object catch (e) {
      // Interrupted by a newer load (another game): not an error.
      if (_loadingGame == game) {
        debugPrint('Music: no track for ${game.name}: $e');
      }
    } finally {
      if (_loadingGame == game) {
        _loadingGame = null;
        _loading = null;
      }
    }
    return _loaded == game;
  }

  /// Eases the volume to [target]; [then] runs once it gets there.
  void _fadeTo(
    AudioPlayer player,
    double target,
    Duration over, {
    Future<void> Function()? then,
  }) {
    _fade?.cancel();
    final from = player.volume;
    const steps = 15;
    var step = 0;
    _fade = Timer.periodic(over ~/ steps, (timer) {
      step++;
      final t = step / steps;
      unawaited(player.setVolume(from + (target - from) * t * t));
      if (step >= steps) {
        timer.cancel();
        if (then != null) {
          unawaited(then());
        }
      }
    });
  }

  Future<void> dispose() async {
    _fade?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _player?.dispose();
  }
}
