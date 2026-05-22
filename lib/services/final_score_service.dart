import '../models/score_model.dart';
import '../repositories/score_repository.dart';
import 'firebase_leaderboard_service.dart';
import 'local_storage_service.dart';

class FinalScoreResult {
  const FinalScoreResult({
    this.submittedToFirebase = false,
    this.queuedOffline = false,
    this.message,
  });

  final bool submittedToFirebase;
  final bool queuedOffline;
  final String? message;
}

/// Handles local persistence and conditional Firebase all-time best upload.
class FinalScoreService {
  FinalScoreService({
    required ScoreRepository scoreRepository,
    required FirebaseLeaderboardService firebaseLeaderboard,
    required LocalStorageService storage,
  }) : _scores = scoreRepository,
       _firebase = firebaseLeaderboard,
       _storage = storage;

  final ScoreRepository _scores;
  final FirebaseLeaderboardService _firebase;
  final LocalStorageService _storage;

  Future<FinalScoreResult> handleFinalScore(ScoreModel score) async {
    if (score.finalScore <= 0) {
      await _scores.saveScore(score);
      return const FinalScoreResult();
    }

    await _scores.saveScore(score);
    await _storage.saveHighestLevelIfHigher(score.gameType, score.level);

    final localBest = await _scores.getBestScore(score.gameType);
    if (score.finalScore > localBest) {
      await _scores.updateBestScore(score.gameType, score.finalScore);
    }

    final submittedBest = await _scores.getSubmittedAllTimeBest(score.gameType);
    if (score.finalScore <= submittedBest) {
      return const FinalScoreResult();
    }

    final playerName = _storage.getPlayerName();
    if (playerName == null || playerName.isEmpty) {
      await _firebase.queuePendingAllTimeSubmission(
        score,
        playerName: 'Player',
      );
      return const FinalScoreResult(
        queuedOffline: true,
        message:
            'Set your name in Settings to upload leaderboard scores when you beat your best.',
      );
    }

    final submitted = await _firebase.submitAllTimeBest(
      score: score,
      playerName: playerName,
    );

    if (submitted) {
      return const FinalScoreResult(
        submittedToFirebase: true,
        message: 'New all-time best uploaded to the leaderboard.',
      );
    }

    return const FinalScoreResult(
      queuedOffline: true,
      message: 'Score queued for leaderboard sync when online.',
    );
  }
}
