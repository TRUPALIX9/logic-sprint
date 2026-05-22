import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/constants/app_config.dart';
import 'package:logic_sprint/core/utils/player_name_validator.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/models/leaderboard_score_model.dart';
import 'package:logic_sprint/services/leaderboard_cache_service.dart';
import 'package:logic_sprint/services/leaderboard_service.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LeaderboardScoreModel', () {
    test('serializes and deserializes json', () {
      const model = LeaderboardScoreModel(
        id: 'abc',
        playerName: 'Ace',
        score: 120,
        gameType: 'quickMath',
        difficulty: 'hard',
        createdAt: null,
        appVersion: '1.0.0',
      );

      final restored = LeaderboardScoreModel.fromJson(model.toJson());
      expect(restored.id, 'abc');
      expect(restored.playerName, 'Ace');
      expect(restored.score, 120);
      expect(restored.gameType, 'quickMath');
      expect(restored.difficulty, 'hard');
      expect(restored.appVersion, '1.0.0');
    });
  });

  group('PlayerNameValidator', () {
    test('accepts valid names', () {
      expect(PlayerNameValidator.validate('Player_One-2'), isNull);
    });

    test('rejects invalid characters', () {
      expect(PlayerNameValidator.validate('bad@name'), isNotNull);
    });

    test('rejects names longer than 20 characters', () {
      expect(PlayerNameValidator.validate('abcdefghijklmnopqrstu'), isNotNull);
    });
  });

  group('LeaderboardService', () {
    late LocalStorageService storage;
    late LeaderboardCacheService cache;
    late LeaderboardService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      cache = LeaderboardCacheService(storage);
      service = LeaderboardService(
        storage: storage,
        cache: cache,
        firestore: null,
      );
    });

    test('enforces daily submission limit', () async {
      for (var i = 0; i < AppConfig.maxDailyLeaderboardSubmissions; i++) {
        await storage.recordLeaderboardSubmission();
      }
      expect(service.canSubmitToday(), isFalse);

      final result = await service.submitScore(
        playerName: 'Player',
        score: 50,
        gameType: GameType.quickMath,
        difficulty: DifficultyLevel.easy,
      );
      expect(result.success, isFalse);
      expect(
        result.message,
        contains('Daily leaderboard submission limit reached'),
      );
    });

    test('uses cache when younger than 10 minutes', () async {
      final scores = [
        const LeaderboardScoreModel(
          id: '1',
          playerName: 'Cached',
          score: 90,
          gameType: 'quickMath',
          difficulty: 'easy',
          createdAt: null,
          appVersion: '1.0.0',
        ),
      ];
      await cache.saveScores(scores);

      final result = await service.loadLeaderboard();
      expect(result.fromCache, isTrue);
      expect(result.scores, hasLength(1));
      expect(result.scores.first.playerName, 'Cached');
    });

    test('refresh cooldown blocks forced refresh', () async {
      await cache.saveScores([
        const LeaderboardScoreModel(
          id: '1',
          playerName: 'Cached',
          score: 40,
          gameType: 'trueFalse',
          difficulty: 'medium',
          createdAt: null,
          appVersion: '1.0.0',
        ),
      ]);
      await cache.markRefreshAttempt();

      final result = await service.loadLeaderboard(forceRefresh: true);
      expect(result.fromCache, isTrue);
      expect(result.infoMessage, contains('Refresh available'));
    });

    test(
      'returns unavailable message when firestore fails without cache',
      () async {
        final result = await service.loadLeaderboard();
        expect(result.scores, isEmpty);
        expect(
          result.errorMessage,
          'Online leaderboard is temporarily unavailable.',
        );
      },
    );

    test('filters cached scores locally without extra queries', () {
      final scores = [
        const LeaderboardScoreModel(
          id: '1',
          playerName: 'A',
          score: 10,
          gameType: 'quickMath',
          difficulty: 'easy',
          createdAt: null,
          appVersion: '1.0.0',
        ),
        const LeaderboardScoreModel(
          id: '2',
          playerName: 'B',
          score: 20,
          gameType: 'trueFalse',
          difficulty: 'hard',
          createdAt: null,
          appVersion: '1.0.0',
        ),
      ];

      final filtered = LeaderboardService.applyFilters(
        scores,
        gameFilter: LeaderboardGameFilter.trueFalse,
        difficultyFilter: LeaderboardDifficultyFilter.hard,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.playerName, 'B');
    });
  });

  group('LeaderboardCacheService', () {
    test('cache expires after 10 minutes', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final cache = LeaderboardCacheService(storage);

      await cache.saveScores([
        const LeaderboardScoreModel(
          id: '1',
          playerName: 'Old',
          score: 15,
          gameType: 'quickMath',
          difficulty: 'easy',
          createdAt: null,
          appVersion: '1.0.0',
        ),
      ]);

      final expiredTimestamp = DateTime.now().subtract(
        const Duration(minutes: 11),
      );
      await storage.setLeaderboardCacheTimestamp(expiredTimestamp);

      expect(cache.isCacheValid(), isFalse);
    });
  });
}
