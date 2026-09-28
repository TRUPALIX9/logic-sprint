import 'package:flutter_test/flutter_test.dart';
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
    now = DateTime.utc(2026, 9, 11, 10);
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
    test('saves the name and tag once the server accepts them', () async {
      expect(await leaderboard.claimName(' NEON_FOX ', 420), isNull);
      expect((api.name, api.tag), ('NEON_FOX', 420));
      expect(leaderboard.savedName, 'NEON_FOX');
      expect(leaderboard.displayName, 'NEON_FOX#0420');
    });

    test('rejects invalid, taken, and offline attempts', () async {
      expect(await leaderboard.claimName('bad!', 1), isNotNull);
      expect(await leaderboard.claimName('AXON', 10000), isNotNull);
      api.taken.add('axon#0001');
      expect(await leaderboard.claimName('AXON', 1), contains('AXON#0001'));
      expect(await leaderboard.claimName('AXON', 2), isNull, reason: 'free');
      api.online = false;
      expect(await leaderboard.claimName('NEW_ONE', 3), isNotNull);
      expect(leaderboard.displayName, 'AXON#0002');
    });

    test('suggests a free tag, or a random one offline', () async {
      expect(await leaderboard.suggestTag('AXON'), 1234);
      api.online = false;
      expect(await leaderboard.suggestTag('AXON'), inInclusiveRange(0, 9999));
    });

    test('a name from before tags learns its tag from the server', () async {
      await storage.setPlayerName('NEON');
      api.tag = 77;
      await leaderboard.load(_math, _easy);
      await pumpEventQueue();
      expect(leaderboard.displayName, 'NEON#0077');
    });

    test('a new name shows on the cached rows right away', () async {
      api.rows = [_row('me', 'OLD#0001', 990), _row('a', 'AXON', 980)];
      await leaderboard.load(_math, _easy);
      await leaderboard.claimName('NEW', 5);
      api.online = false;
      final load = await leaderboard.load(_math, _easy, offline: true);
      expect(load.entries.first.playerName, 'NEW#0005');
    });
  });

  group('load', () {
    test('serves the cache until the next 00:00 UTC', () async {
      final first = await leaderboard.load(_math, _easy);
      expect(first.entries.single.playerName, 'AXON');
      expect(first.myRank, 7);
      expect(first.changed, isTrue, reason: 'first look');
      expect(first.previous, isNull);
      expect(leaderboard.fetchedAt!.isAtSameMomentAs(now), isTrue);

      now = DateTime.utc(2026, 9, 11, 23, 59);
      final later = await leaderboard.load(_math, _easy);
      expect(api.fetches, 1);
      expect(later.changed, isFalse);

      // Two minutes later, but past 00:00 UTC.
      now = DateTime.utc(2026, 9, 12, 0, 1);
      expect(leaderboard.due, isTrue);
      await leaderboard.load(_math, _easy);
      expect(api.fetches, 2);
    });

    test('one fetch fills every board at once', () async {
      api.rows = [
        _row('a', 'AXON', 980),
        {
          ..._row('b', 'BOLT', 500),
          'game_type': 'rocketLaunch',
          'difficulty': 'medium',
        },
      ];
      await leaderboard.load(_math, _easy);
      final rocket = await leaderboard.load(
        GameId.rocketLaunch,
        GameId.rampDifficulty,
      );
      expect(api.fetches, 1);
      expect(rocket.entries.single.playerName, 'BOLT');
      final empty = await leaderboard.load(_math, Difficulty.hard);
      expect(empty.entries, isEmpty);
      expect(api.fetches, 1);
    });

    test('the next reset is the coming 00:00 UTC', () {
      expect(
        Leaderboard.nextReset(DateTime.utc(2026, 9, 11, 23, 30)),
        DateTime.utc(2026, 9, 12),
      );
      expect(
        Leaderboard.lastReset(DateTime.utc(2026, 9, 11, 0, 0)),
        DateTime.utc(2026, 9, 11),
      );
    });

    test(
      'a new best moves the player on their own board, no refetch',
      () async {
        await leaderboard.claimName('NEON', 7);
        api.rows = [_row('a', 'AXON', 980), _row('b', 'BOLT', 500)];
        await leaderboard.load(_math, _easy);

        await leaderboard.recordRun(_result(score: 10, previousBest: 20));
        expect((await leaderboard.load(_math, _easy)).changed, isFalse);

        await leaderboard.recordRun(_result(score: 700, previousBest: 20));
        final after = await leaderboard.load(_math, _easy);
        expect(api.fetches, 1, reason: 'others see it after the reset');
        expect(api.runs.last.$3, 700, reason: 'still sent to the server');
        expect(after.changed, isTrue);
        expect(after.entries.map((e) => e.playerName), [
          'AXON',
          'NEON#0007',
          'BOLT',
        ]);
        expect((after.previousMyRank, after.myRank), (7, 2));
        expect(after.moves['me'], const RankMove(RankMoveKind.entered));
        expect(
          (await leaderboard.load(_math, _easy)).changed,
          isFalse,
          reason: 'animates once',
        );
      },
    );

    test('snapshots persist; an unchanged board keeps the older one', () async {
      await leaderboard.load(_math, _easy);
      api
        ..rows = [_row('b', 'BOLT', 990), _row('a', 'AXON', 980)]
        ..rank = 3;
      now = DateTime.utc(2026, 9, 12, 9);
      expect((await leaderboard.load(_math, _easy)).changed, isTrue);

      // App restart, same day: served from the cache, chips intact.
      final reopened = Leaderboard(storage, api: api, now: () => now);
      final cached = await reopened.load(_math, _easy);
      expect(api.fetches, 2);
      expect(cached.changed, isFalse);
      expect(cached.previous!.map((e) => e.playerId), ['a']);
      expect(cached.previousMyRank, 7);
      expect(cached.moves['b']!.kind, RankMoveKind.entered);

      // Next day, nothing moved: no animation, same "before".
      now = DateTime.utc(2026, 9, 13, 9);
      final unchanged = await reopened.load(_math, _easy);
      expect(api.fetches, 3);
      expect(unchanged.changed, isFalse);
      expect(unchanged.previous!.map((e) => e.playerId), ['a']);
      expect(unchanged.previousMyRank, 7);
    });

    test('only a rank change still counts as a change', () async {
      await leaderboard.load(_math, _easy);
      api.rank = 5;
      now = DateTime.utc(2026, 9, 12, 9);
      final load = await leaderboard.load(_math, _easy);
      expect(load.changed, isTrue);
      expect((load.previousMyRank, load.myRank), (7, 5));
    });

    test('Refresh pulls every board now, then waits 30 minutes', () async {
      await leaderboard.load(_math, _easy);
      api
        ..rows = [_row('b', 'BOLT', 990), _row('a', 'AXON', 980)]
        ..rank = 3;
      expect(leaderboard.refreshWait(), Duration.zero);

      final pulled = await leaderboard.load(_math, _easy, refresh: true);
      expect(api.fetches, 2);
      expect(pulled.changed, isTrue);
      expect(pulled.entries.first.playerName, 'BOLT');
      expect(leaderboard.refreshWait(), const Duration(minutes: 30));

      now = now.add(const Duration(minutes: 29));
      await leaderboard.load(_math, _easy, refresh: true);
      expect(api.fetches, 2, reason: 'still cooling down: cache served');

      now = now.add(const Duration(minutes: 2));
      await leaderboard.load(_math, _easy, refresh: true);
      expect(api.fetches, 3);

      now = now.subtract(const Duration(hours: 3));
      expect(
        leaderboard.refreshWait(),
        const Duration(minutes: 30),
        reason: 'a clock set backwards never lengthens it',
      );
    });

    test('a Refresh that fails does not start the cooldown', () async {
      await leaderboard.load(_math, _easy);
      api.online = false;
      final failed = await leaderboard.load(_math, _easy, refresh: true);
      expect(failed.message, contains('offline'));
      expect(leaderboard.refreshWait(), Duration.zero);
    });

    test('naming yourself refetches once so your row appears', () async {
      await leaderboard.load(_math, _easy);
      api.rows = [_row('a', 'AXON', 980), _row('me', 'NEON#0007', 500)];
      await leaderboard.claimName('NEON', 7);
      final load = await leaderboard.load(_math, _easy);
      expect(api.fetches, 2);
      expect(load.entries.last.playerName, 'NEON#0007');
      expect(leaderboard.refreshWait(), Duration.zero, reason: 'free');
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
      expect(cached.message, contains('offline'));
    });

    test('without a connection, serves the cache without trying', () async {
      await leaderboard.load(_math, _easy);
      now = now.add(const Duration(days: 1));
      final offline = await leaderboard.load(_math, _easy, offline: true);
      expect(api.fetches, 1);
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
