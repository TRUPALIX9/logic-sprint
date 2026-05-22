import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/config/admob_config.dart';

void main() {
  group('AdMobConfig', () {
    test('rewarded unit uses test id in debug builds', () {
      expect(AdMobConfig.rewardedUnitId(debug: true), AdMobConfig.rewardedTest);
    });

    test('rewarded unit uses production id in release builds', () {
      expect(
        AdMobConfig.rewardedUnitId(debug: false),
        AdMobConfig.rewardedProduction,
      );
    });

    test('banner unit uses test id in debug builds', () {
      expect(AdMobConfig.bannerUnitId(debug: true), AdMobConfig.bannerTest);
    });

    test('banner unit uses production id in release builds', () {
      expect(
        AdMobConfig.bannerUnitId(debug: false),
        AdMobConfig.bannerProduction,
      );
    });
  });
}
