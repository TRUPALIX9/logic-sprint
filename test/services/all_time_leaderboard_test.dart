import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/constants/life_game_constants.dart';
import 'package:logic_sprint/models/game_model.dart';
import 'package:logic_sprint/models/leaderboard_entry.dart';
import 'package:logic_sprint/models/score_model.dart';
import 'package:logic_sprint/repositories/score_repository.dart';
import 'package:logic_sprint/services/final_score_service.dart';
import 'package:logic_sprint/services/firebase_leaderboard_service.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScoreModel _score({
  required GameType game,
  int finalScore = 100,
  int level = 3,
}) {
  return ScoreModel(
    gameType: game,
    difficulty: LifeGameConstants.storageDifficulty,
    finalScore: finalScore,
    bestScore: finalScore,
    previousBestScore: 0,
    correctAnswers: 5,
    wrongAnswers: 1,
    accuracyPercentage: 80,
    level: level,
    usedSecondLife: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScoreRepository', () {
    late LocalStorageService storage;
    late ScoreRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      repo = ScoreRepository(storage);
    });

    test('tracks submitted all-time best separately from local best', () async {
      await repo.updateBestScore(GameType.quickMath, 500);
      await repo.updateSubmittedAllTimeBest(GameType.quickMath, 400);

      expect(await repo.getBestScore(GameType.quickMath), 500);
      expect(await repo.getSubmittedAllTimeBest(GameType.quickMath), 400);
    });

    test('saves score history on every final score', () async {
      await repo.saveScore(_score(game: GameType.quickMath, finalScore: 12));
      final raw = storage.getScoreHistoryJson();
      expect(raw, isNotNull);
      final list = jsonDecode(raw!) as List;
      expect(list, hasLength(1));
    });

    test('caches leaderboard per game with today date', () async {
      const entries = [
        LeaderboardEntry(
          playerId: 'u1',
          playerName: 'Ace',
          gameType: GameType.quickMath,
          score: 900,
          level: 5,
          usedSecondLife: false,
        ),
      ];
      await repo.saveCachedLeaderboard(GameType.quickMath, entries);
      expect(storage.isLeaderboardFetchedToday(GameType.quickMath), isTrue);
      final cached = await repo.getCachedLeaderboard(GameType.quickMath);
      expect(cached.first.score, 900);
    });

    test('shouldAutoFetch when not fetched today', () async {
      expect(repo.shouldAutoFetchLeaderboard(GameType.emojiMatch), isTrue);
    });
  });

  group('FirebaseLeaderboardService pending queue', () {
    late LocalStorageService storage;
    late ScoreRepository repo;
    late FirebaseLeaderboardService firebase;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      repo = ScoreRepository(storage);
      firebase = FirebaseLeaderboardService(
        storage: storage,
        scoreRepository: repo,
        firestore: null,
      );
    });

    test('keeps only highest pending score per game', () async {
      await firebase.queuePendingAllTimeSubmission(
        _score(game: GameType.launchRocket, finalScore: 1500),
        playerName: 'Player',
      );
      await firebase.queuePendingAllTimeSubmission(
        _score(game: GameType.launchRocket, finalScore: 1400),
        playerName: 'Player',
      );
      await firebase.queuePendingAllTimeSubmission(
        _score(game: GameType.launchRocket, finalScore: 1860),
        playerName: 'Player',
      );

      final raw = storage.getPendingSubmissionsJson();
      final list = jsonDecode(raw!) as List;
      expect(list, hasLength(1));
      expect(list.first['score'], 1860);
    });

    test('does not queue lower score than existing pending', () async {
      await firebase.queuePendingAllTimeSubmission(
        _score(game: GameType.patternLock, finalScore: 200),
        playerName: 'P',
      );
      await firebase.queuePendingAllTimeSubmission(
        _score(game: GameType.patternLock, finalScore: 100),
        playerName: 'P',
      );

      final raw = storage.getPendingSubmissionsJson();
      final list = jsonDecode(raw!) as List;
      expect(list.first['score'], 200);
    });
  });

  group('FinalScoreService', () {
    late LocalStorageService storage;
    late ScoreRepository repo;
    late FirebaseLeaderboardService firebase;
    late FinalScoreService handler;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      repo = ScoreRepository(storage);
      firebase = FirebaseLeaderboardService(
        storage: storage,
        scoreRepository: repo,
        firestore: null,
      );
      handler = FinalScoreService(
        scoreRepository: repo,
        firebaseLeaderboard: firebase,
        storage: storage,
      );
    });

    test('does not bump submitted best when score is lower', () async {
      await repo.updateSubmittedAllTimeBest(GameType.colorSequence, 300);
      await handler.handleFinalScore(
        _score(game: GameType.colorSequence, finalScore: 250),
      );
      expect(await repo.getSubmittedAllTimeBest(GameType.colorSequence), 300);
    });

    test(
      'updates local best without firebase when not beating submitted',
      () async {
        await repo.updateSubmittedAllTimeBest(GameType.emojiMatch, 500);
        await handler.handleFinalScore(
          _score(game: GameType.emojiMatch, finalScore: 450),
        );
        expect(await repo.getBestScore(GameType.emojiMatch), 450);
        expect(await repo.getSubmittedAllTimeBest(GameType.emojiMatch), 500);
      },
    );
  });

  group('Leaderboard fetch without Firestore', () {
    test('returns cached entries when offline', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final repo = ScoreRepository(storage);
      await repo.saveCachedLeaderboard(GameType.quickMath, const [
        LeaderboardEntry(
          playerId: 'a',
          playerName: 'Cached',
          gameType: GameType.quickMath,
          score: 42,
          level: 1,
          usedSecondLife: false,
        ),
      ]);

      final firebase = FirebaseLeaderboardService(
        storage: storage,
        scoreRepository: repo,
        firestore: null,
      );

      final result = await firebase.fetchAllTimeLeaderboard(
        gameType: GameType.quickMath,
        forceRefresh: true,
      );
      expect(result.entries.first.playerName, 'Cached');
      expect(result.fromCache, isTrue);
    });
  });
}
