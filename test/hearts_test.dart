import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/game.dart';
import 'package:logic_sprint/models/round_result.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:logic_sprint/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _app([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppState(Storage(await SharedPreferences.getInstance()));
}

const _run = RoundResult(
  game: GameId.quickMath,
  difficulty: Difficulty.easy,
  score: 60,
  correct: 5,
  duration: Duration(seconds: 30),
  previousBest: 0,
);

void main() {
  test('no free hearts: new players start with none', () async {
    final app = await _app();
    expect(app.hearts, 0);
    expect(app.canEarnHeart, isFalse);
    expect(await app.useHeart(), isFalse);
  });

  test('each finished run unlocks one heart ad', () async {
    final app = await _app();
    await app.recordRound(_run);
    expect(app.canEarnHeart, isTrue);

    await app.earnHeart();
    expect(app.hearts, 1);
    expect(app.canEarnHeart, isFalse, reason: 'one heart ad per run');

    await app.earnHeart();
    expect(app.hearts, 1);

    await app.recordRound(_run);
    await app.earnHeart();
    expect(app.hearts, 2);
  });

  test('spending a heart', () async {
    final app = await _app({'hearts': 2});
    expect(await app.useHeart(), isTrue);
    expect(app.hearts, 1);
  });

  test('heart ads stop at the cap', () async {
    final app = await _app({'hearts': AppState.maxHearts});
    await app.recordRound(_run);
    expect(app.canEarnHeart, isFalse);
    await app.earnHeart();
    expect(app.hearts, AppState.maxHearts);
  });
}
