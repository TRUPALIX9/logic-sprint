import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/config.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/leaderboard_entry.dart';
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

LeaderboardEntry _entry(String id, [int score = 100]) => LeaderboardEntry(
  playerId: id,
  playerName: id.toUpperCase(),
  score: score,
  game: _math,
  difficulty: _easy,
);

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

    test('refetches boards cached before the name was set', () async {
      await leaderboard.load(_math, _easy);
      await leaderboard.claimName('NEON_FOX');
      await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(2));
    });
  });

  group('load', () {
    test('serves the cache until the next local calendar day', () async {
      final first = await leaderboard.load(_math, _easy);
      expect(first.entries.single.playerName, 'AXON');
      expect(first.myRank, 7);
      expect(first.changed, isTrue, reason: 'first look');
      expect(first.previous, isNull);

      now = DateTime(2026, 9, 11, 23, 59);
      final later = await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(1));
      expect(later.changed, isFalse);

      // Two minutes later, but a new day.
      now = DateTime(2026, 9, 12, 0, 1);
      await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(2));
    });

    test('a new personal best refetches, keeping the old snapshot', () async {
      await leaderboard.load(_math, _easy);
      api
        ..rows = [_row('me', 'NEON', 1000), _row('a', 'AXON', 980)]
        ..rank = 1;

      await leaderboard.recordRun(_result(score: 10, previousBest: 20));
      await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(1), reason: 'not a best: cache kept');

      await leaderboard.recordRun(_result(score: 1000, previousBest: 20));
      final after = await leaderboard.load(_math, _easy);
      expect(api.topCalls, hasLength(2));
      expect(after.changed, isTrue);
      expect(after.previous!.single.playerId, 'a');
      expect((after.previousMyRank, after.myRank), (7, 1));
      expect(after.moves, {
        'me': const RankMove(RankMoveKind.entered),
        'a': const RankMove(RankMoveKind.down, places: 1, from: 0),
      });
    });

    test('snapshots persist; an unchanged board keeps the older one', () async {
      await leaderboard.load(_math, _easy);
      api
        ..rows = [_row('b', 'BOLT', 990), _row('a', 'AXON', 980)]
        ..rank = 3;
      now = DateTime(2026, 9, 12, 9);
      expect((await leaderboard.load(_math, _easy)).changed, isTrue);

      // App restart, same day: served from the cache, chips intact.
      final reopened = Leaderboard(storage, api: api, now: () => now);
      final cached = await reopened.load(_math, _easy);
      expect(api.topCalls, hasLength(2));
      expect(cached.changed, isFalse);
      expect(cached.previous!.map((e) => e.playerId), ['a']);
      expect(cached.previousMyRank, 7);
      expect(cached.moves['b']!.kind, RankMoveKind.entered);

      // Next day, nothing moved: no animation, same "before".
      now = DateTime(2026, 9, 13, 9);
      final unchanged = await reopened.load(_math, _easy);
      expect(api.topCalls, hasLength(3));
      expect(unchanged.changed, isFalse);
      expect(unchanged.previous!.map((e) => e.playerId), ['a']);
      expect(unchanged.previousMyRank, 7);
    });

    test('only a rank change still counts as a change', () async {
      await leaderboard.load(_math, _easy);
      api.rank = 5;
      now = DateTime(2026, 9, 12, 9);
      final load = await leaderboard.load(_math, _easy);
      expect(load.changed, isTrue);
      expect((load.previousMyRank, load.myRank), (7, 5));
    });

    test('reads caches written before snapshots existed', () async {
      await storage.setLeaderboardCache(
        jsonEncode({
          'quickMath_easy': {
            'at': now.millisecondsSinceEpoch,
            'rank': 7,
            'rows': [_row('a', 'AXON', 980)],
          },
        }),
      );
      final load = await leaderboard.load(_math, _easy);
      expect(api.topCalls, isEmpty);
      expect(load.entries.single.playerName, 'AXON');
      expect(load.previous, isNull);
    });

    test('a free refresh (no ad) waits 5 minutes', () async {
      expect(leaderboard.refreshWait(), Duration.zero);
      await leaderboard.load(_math, _easy, refresh: true);
      expect(api.topCalls, hasLength(1));
      expect(
        leaderboard.refreshWait(),
        AppConfig.leaderboardFreeRefreshCooldown,
      );

      now = now.add(const Duration(minutes: 4));
      final early = await leaderboard.load(_math, _easy, refresh: true);
      expect(api.topCalls, hasLength(1));
      expect(early.message, 'Refresh available in 60s');
      expect(early.entries, hasLength(1), reason: 'still shows the board');

      now = now.add(const Duration(seconds: 61));
      await leaderboard.load(_math, _easy, refresh: true);
      expect(api.topCalls, hasLength(2));
    });

    test('a rewarded refresh waits 30 seconds', () async {
      await leaderboard.load(_math, _easy, refresh: true, rewarded: true);
      expect(leaderboard.refreshWait(), const Duration(seconds: 30));

      now = now.add(const Duration(seconds: 29));
      final early = await leaderboard.load(
        _math,
        _easy,
        refresh: true,
        rewarded: true,
      );
      expect(early.message, 'Refresh available in 1s');
      expect(api.topCalls, hasLength(1));

      now = now.add(const Duration(seconds: 2));
      expect(leaderboard.refreshWait(), Duration.zero);
      await leaderboard.load(_math, _easy, refresh: true, rewarded: true);
      expect(api.topCalls, hasLength(2));
    });

    test('a clock set backwards never lengthens the cooldown', () async {
      await leaderboard.load(_math, _easy, refresh: true, rewarded: true);
      now = now.subtract(const Duration(hours: 3));
      expect(leaderboard.refreshWait(), const Duration(seconds: 30));
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

    test('without a connection, serves the cache without trying', () async {
      await leaderboard.load(_math, _easy);
      now = now.add(const Duration(days: 1));
      final offline = await leaderboard.load(_math, _easy, offline: true);
      expect(api.topCalls, hasLength(1));
      expect(offline.entries, hasLength(1));
      expect(offline.message, contains('saved scores'));
    });
  });

  group('rankMoves', () {
    test('climbers, fallers, entrants and unchanged rows', () {
      final before = [_entry('a'), _entry('b'), _entry('c'), _entry('d')];
      final after = [_entry('c'), _entry('b'), _entry('e'), _entry('a')];
      expect(rankMoves(before, after), {
        'c': const RankMove(RankMoveKind.up, places: 2, from: 2),
        'b': const RankMove(RankMoveKind.same, from: 1),
        'e': const RankMove(RankMoveKind.entered),
        'a': const RankMove(RankMoveKind.down, places: 3, from: 0),
      });
    });

    test('an empty "before" makes everyone an entrant', () {
      expect(rankMoves(const [], [_entry('a')]), {
        'a': const RankMove(RankMoveKind.entered),
      });
    });

    test('sameStandings compares players and scores in order', () {
      expect(sameStandings([_entry('a', 5)], [_entry('a', 5)]), isTrue);
      expect(sameStandings([_entry('a', 5)], [_entry('a', 6)]), isFalse);
      expect(
        sameStandings([_entry('a'), _entry('b')], [_entry('b'), _entry('a')]),
        isFalse,
      );
      expect(sameStandings([_entry('a')], const []), isFalse);
    });
  });
}
