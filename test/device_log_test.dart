import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/models/device_log.dart';
import 'package:logic_sprint/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ad events are kept in order and counted by kind', () async {
    final storage = Storage(await SharedPreferences.getInstance());
    final at = DateTime(2026, 11, 20, 9, 41);
    await storage.addAdEvent(
      AdEvent(kind: AdKind.revive, outcome: AdOutcome.rewarded, at: at),
    );
    await storage.addAdEvent(
      AdEvent(kind: AdKind.heart, outcome: AdOutcome.noReward, at: at),
    );
    await storage.addAdEvent(
      AdEvent(kind: AdKind.banner, outcome: AdOutcome.shown, at: at),
    );
    await storage.addAdEvent(
      AdEvent(kind: AdKind.banner, outcome: AdOutcome.shown, at: at),
    );

    final reopened = Storage(await SharedPreferences.getInstance());
    expect(
      [for (final e in reopened.adLog) e.kind],
      [AdKind.revive, AdKind.heart],
      reason: 'banners are only counted, not logged one by one',
    );
    expect(reopened.adLog.first.outcome, AdOutcome.rewarded);
    expect(reopened.adLog.first.at, at);
    expect(reopened.adCounts, {
      AdKind.revive: 1,
      AdKind.heart: 1,
      AdKind.refresh: 0,
      AdKind.banner: 2,
    });
    expect(reopened.adCount(AdKind.heart, AdOutcome.rewarded), 0);
    expect(reopened.adCount(AdKind.heart, AdOutcome.noReward), 1);
  });

  test(
    'the ad log keeps the latest ads but the totals keep counting',
    () async {
      final storage = Storage(await SharedPreferences.getInstance());
      final at = DateTime(2026);
      for (var i = 0; i < Storage.adLogLimit + 20; i++) {
        await storage.addAdEvent(
          AdEvent(kind: AdKind.revive, outcome: AdOutcome.rewarded, at: at),
        );
      }
      expect(storage.adLog, hasLength(Storage.adLogLimit));
      expect(storage.adCounts[AdKind.revive], Storage.adLogLimit + 20);
    },
  );

  test('a broken log reads as empty instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      'adLog': 'not json',
      'nameLog': '[["OK",1,0],["bad"]]',
    });
    final storage = Storage(await SharedPreferences.getInstance());
    expect(storage.adLog, isEmpty);
    expect([for (final n in storage.nameLog) n.name], ['OK']);
  });
}
