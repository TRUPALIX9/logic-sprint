import 'package:audioplayers/audioplayers.dart';

class SoundService {
  SoundService._({AudioPlayer? audioPlayer}) : _audioPlayer = audioPlayer;

  factory SoundService() => SoundService._(
    audioPlayer: AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  );

  /// No-op implementation for unit tests (avoids platform channel plugins).
  factory SoundService.silent() => SoundService._();

  final AudioPlayer? _audioPlayer;
  bool _isEnabled = true;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  Future<void> playCorrect() async {
    final player = _audioPlayer;
    if (!_isEnabled || player == null) {
      return;
    }
    await player.stop();
  }

  Future<void> playWrong() async {
    final player = _audioPlayer;
    if (!_isEnabled || player == null) {
      return;
    }
    await player.stop();
  }
}
