import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/services/ads.dart';

void main() {
  late List<String> calls;
  RewardOutcome outcome() => RewardOutcome(
    onReward: () => calls.add('reward'),
    onDone: () => calls.add('done'),
  );

  setUp(() => calls = []);

  test('Android order (reward, then dismissal) revives at once', () {
    fakeAsync((async) {
      outcome()
        ..rewarded()
        ..dismissed();
      expect(calls, ['reward']);
      async.elapse(const Duration(seconds: 5));
      expect(calls, ['reward']);
    });
  });

  test('iOS order (dismissal, then a late reward) still revives', () {
    fakeAsync((async) {
      final o = outcome()..dismissed();
      async.elapse(const Duration(milliseconds: 400));
      expect(calls, isEmpty, reason: 'waiting for a late reward');
      o.rewarded();
      expect(calls, ['reward']);
      async.elapse(const Duration(seconds: 5));
      expect(calls, ['reward']);
    });
  });

  test('closed early (no reward) ends the run after the grace', () {
    fakeAsync((async) {
      final o = outcome()..dismissed();
      async.elapse(const Duration(milliseconds: 1499));
      expect(calls, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(calls, ['done']);
      o.rewarded();
      expect(calls, ['done'], reason: 'settles only once');
    });
  });

  test('failing to show ends the run at once', () {
    fakeAsync((async) {
      outcome().failed();
      expect(calls, ['done']);
    });
  });
}
