import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/config.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/leaderboard_entry.dart';
import 'package:logic_sprint/models/round_result.dart';

RoundResult _result({
  int score = 10,
  int correct = 1,
  int wrong = 0,
  int previousBest = 0,
}) => RoundResult(
  game: GameId.quickMath,
  difficulty: Difficulty.easy,
  score: score,
  correct: correct,
  wrong: wrong,
  previousBest: previousBest,
);

void main() {
  group('RoundResult', () {
    test('accuracy is a rounded percentage, 0 with no attempts', () {
      expect(_result(correct: 2, wrong: 1).accuracy, 67);
      expect(_result(correct: 0, wrong: 0).accuracy, 0);
    });

    test('new best only when the score beats the previous best', () {
      expect(_result(score: 50, previousBest: 40).isNewBest, isTrue);
      expect(_result(score: 50, previousBest: 40).improvement, 10);
      expect(_result(score: 40, previousBest: 40).isNewBest, isFalse);
      expect(_result(score: 0, previousBest: 0).isNewBest, isFalse);
    });
  });

  group('GameId', () {
    test('tryParse round-trips names and rejects unknown ones', () {
      for (final game in GameId.values) {
        expect(GameId.tryParse(game.name), game);
      }
      expect(GameId.tryParse('trueFalse'), isNull);
    });

    test('difficulty games describe each level; ramp games have a note', () {
      for (final game in GameId.values) {
        if (game.hasDifficulty) {
          expect(game.rampNote, isNull);
          for (final difficulty in Difficulty.values) {
            expect(game.detail(difficulty), isNotEmpty);
          }
          expect(game.titleWith(Difficulty.hard), endsWith('HARD'));
        } else {
          expect(game.rampNote, isNotEmpty);
          expect(game.titleWith(Difficulty.hard), game.title);
        }
      }
      expect(GameId.values.where((g) => g.hasDifficulty), [
        GameId.memoryLane,
        GameId.quickMath,
      ]);
    });
  });

  group('PlayerName.validate', () {
    test('accepts letters, numbers, spaces, _ and -', () {
      expect(PlayerName.validate('NEON_FOX'), isNull);
      expect(PlayerName.validate(' kira-x 9 '), isNull);
    });

    test('rejects empty, too long, and symbols', () {
      expect(PlayerName.validate(''), isNotNull);
      expect(PlayerName.validate('   '), isNotNull);
      expect(PlayerName.validate('a' * 21), isNotNull);
      expect(PlayerName.validate('bad!'), isNotNull);
    });
  });

  group('LeaderboardEntry', () {
    final row = {
      'id': 'abc',
      'player_name': 'AXON',
      'score': 980,
      'game_type': 'rocketLaunch',
      'difficulty': 'hard',
      'created_at': '2026-09-11T10:00:00.000Z',
    };

    test('parses a Supabase row and round-trips through toRow', () {
      final entry = LeaderboardEntry.fromRow(row)!;
      expect(entry.playerName, 'AXON');
      expect(entry.game, GameId.rocketLaunch);
      expect(entry.difficulty, Difficulty.hard);
      expect(LeaderboardEntry.fromRow(entry.toRow())!.score, 980);
    });

    test('skips rows for games this build does not know', () {
      expect(
        LeaderboardEntry.fromRow({...row, 'game_type': 'trueFalse'}),
        isNull,
      );
      expect(
        LeaderboardEntry.fromRow({...row, 'difficulty': 'insane'}),
        isNull,
      );
    });
  });
}
