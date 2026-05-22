import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/services/rewarded_ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RewardedAdService', () {
    test('starts not ready without a loaded ad', () {
      final service = RewardedAdService(useTestAds: true);
      expect(service.isReady, isFalse);
      service.dispose();
    });

    test('show without loaded ad does not grant reward', () async {
      final service = RewardedAdService(useTestAds: true);
      var unavailableCalled = false;

      final result = await service.show(
        onAdUnavailable: () => unavailableCalled = true,
      );

      expect(result.rewardEarned, isFalse);
      expect(result.adShown, isFalse);
      expect(unavailableCalled, isTrue);
      service.dispose();
    });

    test('dispose is safe when no ad is loaded', () {
      final service = RewardedAdService(useTestAds: true);
      expect(() => service.dispose(), returnsNormally);
    });
  });

  group('RewardedAdShowResult', () {
    test('early close without reward is not earned', () {
      const result = RewardedAdShowResult(rewardEarned: false, adShown: true);
      expect(result.rewardEarned, isFalse);
    });
  });
}
