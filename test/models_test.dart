import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/config.dart';
import 'package:logic_sprint/core/format.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/leaderboard_entry.dart';
import 'package:logic_sprint/models/round_result.dart';

RoundResult _result({int score = 10, int previousBest = 0}) => RoundResult(
  game: GameId.quickMath,
  difficulty: Difficulty.easy,
  score: score,
  correct: 1,
  duration: const Duration(seconds: 42),
  previousBest: previousBest,
);

void main() {
  group('RoundResult', () {
    test('new best only when the score beats the previous best', () {
      expect(_result(score: 50, previousBest: 40).isNewBest, isTrue);
      expect(_result(score: 50, previousBest: 40).improvement, 10);
      expect(_result(score: 40, previousBest: 40).isNewBest, isFalse);
      expect(_result(score: 0, previousBest: 0).isNewBest, isFalse);
    });
  });

  test('formatDuration shows m:ss, or h:mm:ss past an hour', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 1, seconds: 24)), '1:24');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 10)),
      '1:02:10',
    );
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
      'difficulty': 'medium',
      'duration_ms': 84000,
      'created_at': '2026-09-11T10:00:00.000Z',
    };

    test('parses a Supabase row and round-trips through toRow', () {
      final entry = LeaderboardEntry.fromRow(row)!;
      expect(entry.playerName, 'AXON');
      expect(entry.game, GameId.rocketLaunch);
      expect(entry.duration, const Duration(seconds: 84));
      final again = LeaderboardEntry.fromRow(entry.toRow())!;
      expect(again.score, 980);
      expect(again.duration, entry.duration);
    });

    test('rows without a duration still parse', () {
      expect(
        LeaderboardEntry.fromRow({...row}..remove('duration_ms'))!.duration,
        isNull,
      );
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
