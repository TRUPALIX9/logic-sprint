import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/life_game_constants.dart';
import '../../../core/game/score_calculator.dart';
import '../../../core/utils/score_utils.dart';
import '../../../models/game_model.dart';
import '../../../models/score_model.dart';
import '../../../models/second_life_session.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/sound_service.dart';
import 'emoji_match_models.dart';

class EmojiMatchController extends ChangeNotifier {
  EmojiMatchController({
    required this.storage,
    required this.soundService,
    Random? random,
  }) : random = random ?? Random();

  final LocalStorageService storage;
  final SoundService soundService;
  final Random random;
  final GameType gameType = GameType.emojiMatch;
  final SecondLifeSession secondLife = SecondLifeSession();

  static const DifficultyLevel _storage = LifeGameConstants.storageDifficulty;

  EmojiMatchConfig config = emojiMatchConfigForLevel(1);
  List<EmojiCard> cards = [];
  final List<int> selectedIndexes = [];

  int lives = LifeGameConstants.startingLives;
  int level = 1;
  int score = 0;
  int bestScore = 0;
  int streak = 0;
  int correctMatches = 0;
  int wrongMatches = 0;
  bool isCheckingPair = false;
  bool isRoundComplete = false;
  bool isLoading = true;
  ScoreModel? result;

  int get matchedPairCount => cards.where((card) => card.isMatched).length ~/ 2;

  bool get isGameplayPaused =>
      secondLife.isPausedForRewardAd || secondLife.awaitingSecondLifeDecision;

  String get statusMessage {
    if (isRoundComplete) {
      return 'Game over';
    }
    return 'Match all emoji pairs. Wrong matches cost a life.';
  }

  Future<void> initialize() async {
    resetGame();
    bestScore = storage.getHighScore(gameType, _storage);
    _setupLevelBoard();
    isLoading = false;
    notifyListeners();
  }

  void _setupLevelBoard() {
    config = emojiMatchConfigForLevel(level);
    _createCards();
    selectedIndexes.clear();
    isCheckingPair = false;
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

  Future<void> handleCardTap(int index) async {
    if (isRoundComplete || isCheckingPair || isLoading || isGameplayPaused) {
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
        level += 1;
        isCheckingPair = false;
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!isRoundComplete && !isGameplayPaused) {
          _setupLevelBoard();
          notifyListeners();
        }
        return;
      }
    } else {
      wrongMatches++;
      streak = 0;
      lives -= 1;
      await soundService.playWrong();
      await Future<void>.delayed(config.mismatchRevealDuration);
      first.isFaceUp = false;
      second.isFaceUp = false;
      selectedIndexes.clear();

      if (lives <= 0) {
        isCheckingPair = false;
        _offerGameOverOrSecondLife();
        return;
      }
    }

    isCheckingPair = false;
    notifyListeners();
  }

  void _offerGameOverOrSecondLife() {
    if (!secondLife.secondLifeUsed) {
      secondLife.pauseForSecondLifeOffer();
      notifyListeners();
      return;
    }
    unawaited(endGameFinal());
  }

  Future<void> resumeFromSecondLifeReward() async {
    secondLife.markSecondLifeUsed();
    lives = 1;
    notifyListeners();
  }

  Future<void> endGameFinal() async {
    if (isRoundComplete) {
      return;
    }

    secondLife.endGameFinal();
    isRoundComplete = true;

    final previousBest = bestScore;
    bestScore = await storage.saveHighScoreIfHigher(gameType, _storage, score);

    result = ScoreModel(
      gameType: gameType,
      difficulty: _storage,
      finalScore: score,
      bestScore: bestScore,
      previousBestScore: previousBest,
      correctAnswers: correctMatches,
      wrongAnswers: wrongMatches,
      accuracyPercentage: ScoreUtils.accuracyPercentage(
        correctAnswers: correctMatches,
        wrongAnswers: wrongMatches,
      ),
      level: level,
      usedSecondLife: secondLife.secondLifeUsed,
    );
    notifyListeners();
  }

  void resetGame() {
    secondLife.reset();
    isRoundComplete = false;
    result = null;
    lives = LifeGameConstants.startingLives;
    level = 1;
    score = 0;
    streak = 0;
    correctMatches = 0;
    wrongMatches = 0;
    isCheckingPair = false;
    selectedIndexes.clear();
    isLoading = false;
  }
}
