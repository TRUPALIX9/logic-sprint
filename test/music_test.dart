import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/services/music.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Music.shouldPlay', () {
    bool play({
      bool wanted = true,
      bool foreground = true,
      bool ad = false,
      bool live = true,
    }) => Music.shouldPlay(
      wanted: wanted,
      foreground: foreground,
      adPlaying: ad,
      runLive: live,
    );

    test('plays only in a live run, when on, in front, with no ad', () {
      expect(play(), isTrue);
      expect(play(live: false), isFalse, reason: 'menus are silent');
      expect(play(wanted: false), isFalse);
      expect(play(foreground: false), isFalse);
      expect(play(ad: true), isFalse);
    });

    test('stays quiet under the game', () {
      expect(Music.volume, lessThanOrEqualTo(0.45));
    });

    test('every game has its own track', () {
      final paths = {for (final g in GameId.values) Music.assetFor(g)};
      expect(paths, hasLength(GameId.values.length));
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
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
