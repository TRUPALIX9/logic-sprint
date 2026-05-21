import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  bool _isEnabled = true;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  Future<void> playCorrect() async {
    if (!_isEnabled) {
      return;
    }
    await _audioPlayer.stop();
  }

  Future<void> playWrong() async {
    if (!_isEnabled) {
      return;
    }
    await _audioPlayer.stop();
  }
}
