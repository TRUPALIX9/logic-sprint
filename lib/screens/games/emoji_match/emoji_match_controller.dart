import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game/score_calculator.dart';
import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import 'emoji_match_models.dart';

class EmojiMatchController extends ChangeNotifier {
  EmojiMatchController({
    required this.storage,
    required this.soundService,
    required this.difficulty,
    Random? random,
  }) : random = random ?? Random(),
       config = emojiMatchConfigFor(difficulty);

  final LocalStorageService storage;
  final SoundService soundService;
  final DifficultyLevel difficulty;
  final Random random;
  final GameType gameType = GameType.emojiMatch;
  final EmojiMatchConfig config;

  Timer? _timer;
  List<EmojiCard> cards = [];
  final List<int> selectedIndexes = [];

  int score = 0;
  int streak = 0;
  int remainingSeconds = 0;
  int correctMatches = 0;
  int wrongMatches = 0;
  bool isCheckingPair = false;
  bool isRoundComplete = false;
  bool isWin = false;
  bool isLoading = true;
  ScoreModel? result;

  int get matchedPairCount => cards.where((card) => card.isMatched).length ~/ 2;

  String get statusMessage {
    if (isRoundComplete) {
      return isWin ? 'All pairs matched!' : "Time's up!";
    }
    return 'Find all matching pairs before time runs out.';
  }

  Future<void> initialize() async {
    remainingSeconds = config.totalTime.inSeconds;
    _createCards();
    isLoading = false;
    notifyListeners();
    _startTimer();
  }

  void _createCards() {
    final selectedEmojis = [...emojiPool]..shuffle(random);
    final pairs = selectedEmojis.take(config.pairCount).toList();
    cards = [
      for (final emoji in pairs) ...[
        EmojiCard(id: '${emoji}_a', emoji: emoji),
        EmojiCard(id: '${emoji}_b', emoji: emoji),
      ],
    ]..shuffle(random);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isRoundComplete) {
        return;
      }

      remainingSeconds--;
      if (remainingSeconds <= 0) {
        unawaited(_endGame(win: matchedPairCount == config.pairCount));
      }
      notifyListeners();
    });
  }

  Future<void> handleCardTap(int index) async {
    if (isRoundComplete || isCheckingPair || isLoading) {
      return;
    }

    final card = cards[index];
    if (card.isFaceUp || card.isMatched) {
      return;
    }

    card.isFaceUp = true;
    selectedIndexes.add(index);
    notifyListeners();

    if (selectedIndexes.length == 2) {
      await _checkSelectedPair();
    }
  }

  Future<void> _checkSelectedPair() async {
    isCheckingPair = true;
    notifyListeners();

    final firstIndex = selectedIndexes[0];
    final secondIndex = selectedIndexes[1];
    final first = cards[firstIndex];
    final second = cards[secondIndex];

    if (first.emoji == second.emoji) {
      first.isMatched = true;
      second.isMatched = true;
      correctMatches++;
      streak++;
      score = ScoreCalculator.applyCorrect(
        currentScore: score,
        streakAfterCorrect: streak,
      );
      await soundService.playCorrect();
      selectedIndexes.clear();

      if (cards.every((card) => card.isMatched)) {
        await _endGame(win: true);
        return;
      }
    } else {
      wrongMatches++;
      streak = 0;
      if (config.hasMismatchPenalty) {
        score = ScoreCalculator.applyMismatchPenalty(score, penalty: 2);
      }
      await soundService.playWrong();
      await Future<void>.delayed(config.mismatchRevealDuration);
      first.isFaceUp = false;
      second.isFaceUp = false;
      selectedIndexes.clear();
    }

    isCheckingPair = false;
    notifyListeners();
  }

  Future<void> _endGame({required bool win}) async {
    if (isRoundComplete) {
      return;
    }

    isRoundComplete = true;
    isWin = win;
    _timer?.cancel();

    final previousBest = storage.getHighScore(gameType, difficulty);
    final bestScore = await storage.saveHighScoreIfHigher(
      gameType,
      difficulty,
      score,
    );

    result = ScoreModel(
      gameType: gameType,
      difficulty: difficulty,
      finalScore: score,
      bestScore: bestScore,
      previousBestScore: previousBest,
      correctAnswers: correctMatches,
      wrongAnswers: wrongMatches,
      accuracyPercentage: ScoreUtils.accuracyPercentage(
        correctAnswers: correctMatches,
        wrongAnswers: wrongMatches,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
