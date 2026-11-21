import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/services/music.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Music.shouldPlay', () {
    test('plays only when on, in front, and no ad is showing', () {
      expect(
        Music.shouldPlay(wanted: true, foreground: true, adPlaying: false),
        isTrue,
      );
      expect(
        Music.shouldPlay(wanted: false, foreground: true, adPlaying: false),
        isFalse,
      );
      expect(
        Music.shouldPlay(wanted: true, foreground: false, adPlaying: false),
        isFalse,
      );
      expect(
        Music.shouldPlay(wanted: true, foreground: true, adPlaying: true),
        isFalse,
      );
    });

    test('stays quiet under the game', () {
      expect(Music.volume, lessThanOrEqualTo(0.4));
    });
  });

  group('Music setting', () {
    test('is on by default and remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = Storage(await SharedPreferences.getInstance());
      final app = AppState(storage);
      expect(app.musicOn, isTrue);
      await app.setMusicOn(false);
      expect(AppState(storage).musicOn, isFalse);
    });
  });
}
