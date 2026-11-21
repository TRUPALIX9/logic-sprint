import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

/// A calm background loop under menus and games: `assets/audio/calm_loop.m4a`,
/// composed for LogicSprint by `tool/compose_music.py` (original, no
/// licence needed). It plays quietly while Music is on and pauses while the
/// app is in the background or a full-screen ad is playing.
///
/// The audio session is "ambient": it mixes with music from other apps and
/// follows the iPhone silent switch, like most casual games.
class Music with WidgetsBindingObserver {
  Music({AudioPlayer? player}) : _player = player;

  static const asset = 'assets/audio/calm_loop.m4a';

  /// Quiet on purpose: it should sit under the game, not over it.
  static const volume = 0.35;
  static const _fadeIn = Duration(milliseconds: 1800);

  AudioPlayer? _player;
  bool _wanted = false;
  bool _foreground = true;
  bool _adPlaying = false;
  bool _ready = false;
  Timer? _fade;

  /// Loads the loop and starts it if [on]. Safe to call once at start-up; a
  /// device without audio just stays silent.
  Future<void> start({required bool on}) async {
    WidgetsBinding.instance.addObserver(this);
    _wanted = on;
    try {
      final session = await AudioSession.instance;
      // Ambient: mixes with other apps' audio, obeys the silent switch, and
      // never takes audio focus from someone's music on Android.
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
      final player = _player ??= AudioPlayer(
        handleAudioSessionActivation: false,
        handleInterruptions: false,
      );
      await player.setAsset(asset);
      await player.setLoopMode(LoopMode.one);
      _ready = true;
      _sync();
    } on Object catch (e) {
      debugPrint('Music unavailable: $e');
    }
  }

  /// The player's Music setting.
  set on(bool value) {
    _wanted = value;
    _sync();
  }

  /// A full-screen ad started or ended: rewarded ads play their own sound.
  void adStarted() {
    _adPlaying = true;
    _sync();
  }

  void adEnded() {
    _adPlaying = false;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  /// Whether the loop should be audible right now.
  @visibleForTesting
  static bool shouldPlay({
    required bool wanted,
    required bool foreground,
    required bool adPlaying,
  }) => wanted && foreground && !adPlaying;

  void _sync() {
    final player = _player;
    if (!_ready || player == null) {
      return;
    }
    final play = shouldPlay(
      wanted: _wanted,
      foreground: _foreground,
      adPlaying: _adPlaying,
    );
    if (play && !player.playing) {
      _fadeInFrom(player);
    } else if (!play && player.playing) {
      _fade?.cancel();
      unawaited(player.pause());
    }
  }

  /// Starts from silence and eases up to [volume], so the music never
  /// arrives with a jump.
  void _fadeInFrom(AudioPlayer player) {
    _fade?.cancel();
    unawaited(player.setVolume(0));
    unawaited(player.play());
    const steps = 18;
    var step = 0;
    _fade = Timer.periodic(_fadeIn ~/ steps, (timer) {
      step++;
      final t = step / steps;
      unawaited(player.setVolume(volume * t * t));
      if (step >= steps) {
        timer.cancel();
      }
    });
  }

  Future<void> dispose() async {
    _fade?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _player?.dispose();
  }
}
