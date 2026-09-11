import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _math = GameId.quickMath;
const _easy = Difficulty.easy;

Map<String, dynamic> _row(String name, int score, GameId game, Difficulty d) =>
    {
      'id': name,
      'player_name': name,
      'score': score,
      'game_type': game.name,
      'difficulty': d.name,
      'created_at': '2026-09-11T10:00:00.000Z',
    };

void main() {
  late Storage storage;
  late DateTime now;
  late List<(GameId, Difficulty)> fetches;
  late List<Map<String, dynamic>> inserted;
  late bool online;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = Storage(await SharedPreferences.getInstance());
    now = DateTime(2026, 9, 11, 10);
    fetches = [];
    inserted = [];
    online = true;
  });

  Leaderboard make() => Leaderboard(
    storage,
    appVersion: '1.0.0',
    now: () => now,
    fetchTop: (game, difficulty) async {
      fetches.add((game, difficulty));
      if (!online) {
        throw StateError('offline');
      }
      return [
        _row('AXON', 980, game, difficulty),
        // A stray row for another board must never leak into this one.
        _row('GHOST', 999, GameId.rocketLaunch, Difficulty.hard),
      ];
    },
    insert: (row) async {
      if (!online) {
        throw StateError('offline');
      }
      inserted.add(row);
    },
  );

  group('load', () {
    test('asks for one board and caches it for 10 minutes', () async {
      final leaderboard = make();
      final first = await leaderboard.load(_math, _easy);
      await leaderboard.load(_math, _easy);
      expect(fetches, [(_math, _easy)]);
      expect(first.entries.map((e) => e.playerName), ['AXON']);

      now = now.add(const Duration(minutes: 11));
      await leaderboard.load(_math, _easy);
      expect(fetches, hasLength(2));
    });

    test('caches each game and difficulty separately', () async {
      final leaderboard = make();
      await leaderboard.load(_math, _easy);
      await leaderboard.load(_math, Difficulty.hard);
      await leaderboard.load(GameId.guessColor, GameId.rampDifficulty);
      await leaderboard.load(_math, _easy);
      expect(fetches, [
        (_math, _easy),
        (_math, Difficulty.hard),
        (GameId.guessColor, GameId.rampDifficulty),
      ]);
    });

    test('manual refresh has a 60 s cooldown', () async {
      final leaderboard = make();
      await leaderboard.load(_math, _easy, refresh: true);
      final second = await leaderboard.load(_math, _easy, refresh: true);
      expect(fetches, hasLength(1));
      expect(second.message, startsWith('Refresh available in'));

      now = now.add(const Duration(seconds: 61));
      await leaderboard.load(_math, _easy, refresh: true);
      expect(fetches, hasLength(2));
    });

    test('falls back to the cache, or an offline message', () async {
      final leaderboard = make();
      online = false;
      final empty = await leaderboard.load(_math, _easy);
      expect(empty.entries, isEmpty);
      expect(empty.message, contains('offline'));

      online = true;
      await leaderboard.load(_math, _easy);
      online = false;
      now = now.add(const Duration(minutes: 11));
      final cached = await leaderboard.load(_math, _easy);
      expect(cached.entries, hasLength(1));
      expect(cached.message, contains('saved scores'));
    });
  });

  group('submit', () {
    Future<String?> post(
      Leaderboard leaderboard, {
      String name = 'NEON_FOX',
      int score = 420,
    }) => leaderboard.submit(
      name: name,
      game: _math,
      difficulty: Difficulty.medium,
      score: score,
    );

    test('sends the row, remembers the name, and counts the post', () async {
      final leaderboard = make();
      expect(await post(leaderboard, name: ' NEON_FOX '), isNull);
      expect(inserted.single, {
        'player_name': 'NEON_FOX',
        'score': 420,
        'game_type': 'quickMath',
        'difficulty': 'medium',
        'app_version': '1.0.0',
      });
      expect(leaderboard.savedName, 'NEON_FOX');
      expect(leaderboard.postsLeftToday, 4);
    });

    test('posting refetches only that board next time', () async {
      final leaderboard = make();
      await leaderboard.load(_math, Difficulty.medium);
      await leaderboard.load(_math, _easy);
      await post(leaderboard);
      await leaderboard.load(_math, Difficulty.medium);
      await leaderboard.load(_math, _easy);
      expect(fetches, [
        (_math, Difficulty.medium),
        (_math, _easy),
        (_math, Difficulty.medium),
      ]);
    });

    test('rejects bad names, zero scores, and a sixth post in a day', () async {
      final leaderboard = make();
      expect(await post(leaderboard, name: 'bad!'), isNotNull);
      expect(await post(leaderboard, score: 0), isNotNull);
      for (var i = 0; i < 5; i++) {
        expect(await post(leaderboard), isNull);
      }
      expect(await post(leaderboard), contains('limit'));
      expect(inserted, hasLength(5));

      now = now.add(const Duration(days: 1));
      expect(leaderboard.postsLeftToday, 5);
    });

    test('a failed post is not counted', () async {
      final leaderboard = make();
      online = false;
      expect(await post(leaderboard), isNotNull);
      expect(leaderboard.postsLeftToday, 5);
    });
  });
}
