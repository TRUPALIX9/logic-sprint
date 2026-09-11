import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/round_result.dart';
import 'package:logic_sprint/services/leaderboard.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_leaderboard_api.dart';

const _math = GameId.quickMath;
const _easy = Difficulty.easy;

Map<String, dynamic> _row(String id, String name, int score) => {
  'player_id': id,
  'player_name': name,
  'score': score,
  'game_type': _math.name,
  'difficulty': _easy.name,
  'duration_ms': 60000,
  'best_at': '2026-09-11T10:00:00.000Z',
};

RoundResult _result({int score = 120, int previousBest = 0}) => RoundResult(
  game: _math,
  difficulty: _easy,
  score: score,
  correct: 12,
  duration: const Duration(seconds: 42),
  previousBest: previousBest,
);

void main() {
  late Storage storage;
  late FakeLeaderboardApi api;
  late DateTime now;
  late Leaderboard leaderboard;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = Storage(await SharedPreferences.getInstance());
    api = FakeLeaderboardApi(rows: [_row('a', 'AXON', 980)], rank: 7);
    now = DateTime(2026, 9, 11, 10);
    leaderboard = Leaderboard(storage, api: api, now: () => now);
  });

  group('recordRun', () {
    test('saves History locally and records the run on the server', () async {
      await leaderboard.recordRun(_result());
      expect(leaderboard.history.single.score, 120);
      expect(api.runs.single, (_math, _easy, 120, const Duration(seconds: 42)));
      expect(storage.pendingRuns, isEmpty);
    });

    test('queues runs while offline and sends them in order later', () async {
      api.online = false;
      await leaderboard.recordRun(_result(score: 50));
      await leaderboard.recordRun(_result(score: 70));
      expect(storage.pendingRuns.map((r) => r.score), [50, 70]);
      expect(leaderboard.history.map((r) => r.score), [70, 50]);

      api.online = true;
      expect(await leaderboard.syncPending(), isTrue);
      expect(api.runs.map((r) => r.$3), [50, 70]);
      expect(storage.pendingRuns, isEmpty);
    });

    test('History keeps only the most recent runs', () async {
      for (var i = 0; i < Storage.historyLimit + 5; i++) {
        await leaderboard.recordRun(_result(score: i + 1));
      }
      expect(leaderboard.history, hasLength(Storage.historyLimit));
      expect(leaderboard.history.first.score, Storage.historyLimit + 5);
    });
  });

  group('claimName', () {
    test('saves the name once the server accepts it', () async {
      expect(await leaderboard.claimName(' NEON_FOX '), isNull);
      expect(api.name, 'NEON_FOX');
      expect(leaderboard.savedName, 'NEON_FOX');
    });

    test('rejects invalid, taken, and offline attempts', () async {
      expect(await leaderboard.claimName('bad!'), isNotNull);
      api.takenNames.add('axon');
      expect(await leaderboard.claimName('AXON'), contains('taken'));
      api.online = false;
      expect(await leaderboard.claimName('NEW_ONE'), isNotNull);
      expect(leaderboard.savedName, isNull);
    });
  });

  group('load', () {
    test(
      'fetches the board and rank, then serves the cache for a day',
      () async {
        final first = await leaderboard.load(_math, _easy);
        expect(first.entries.single.playerName, 'AXON');
        expect(first.myRank, 7);

        now = now.add(const Duration(hours: 23));
        await leaderboard.load(_math, _easy);
        expect(api.topCalls, hasLength(1));

        now = now.add(const Duration(hours: 2));
        await leaderboard.load(_math, _easy);
        expect(api.topCalls, hasLength(2));
      },
    );

    test('a new personal best drops that board from the cache', () async {
      await leaderboard.load(_math, _easy);
      await leaderboard.recordRun(_result(score: 10, previousBest: 20));
      await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(1), reason: 'not a best: cache kept');

      await leaderboard.recordRun(_result(score: 30, previousBest: 20));
      await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(2));
    });

    test('manual refresh has a 60 s cooldown', () async {
      await leaderboard.load(_math, _easy, refresh: true);
      final second = await leaderboard.load(_math, _easy, refresh: true);
      expect(api.topCalls, hasLength(1));
      expect(second.message, startsWith('Refresh available in'));

      now = now.add(const Duration(seconds: 61));
      await leaderboard.load(_math, _easy, refresh: true);
      expect(api.topCalls, hasLength(2));
    });

    test('falls back to the cache, or an offline message', () async {
      api.online = false;
      final empty = await leaderboard.load(_math, _easy);
      expect(empty.entries, isEmpty);
      expect(empty.message, contains('offline'));

      api.online = true;
      await leaderboard.load(_math, _easy);
      api.online = false;
      now = now.add(const Duration(days: 2));
      final cached = await leaderboard.load(_math, _easy);
      expect(cached.entries, hasLength(1));
      expect(cached.myRank, 7);
      expect(cached.message, contains('saved scores'));
    });
  });
}
