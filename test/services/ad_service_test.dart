import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/services/ad_service.dart';
import 'package:logic_sprint/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AdMode', () {
    test('fromString parses modes correctly', () {
      expect(AdMode.fromString('simulated'), AdMode.simulated);
      expect(AdMode.fromString('real'), AdMode.real);
      expect(AdMode.fromString('disabled'), AdMode.disabled);
      expect(AdMode.fromString('unknown'), AdMode.simulated); // default fallback
    });

    test('displayName returns descriptive strings', () {
      expect(AdMode.simulated.displayName, contains('Simulated'));
      expect(AdMode.real.displayName, contains('Real'));
      expect(AdMode.disabled.displayName, contains('Disabled'));
    });
  });

  group('AdService Unit Tests', () {
    late LocalStorageService storage;
    late AdService adService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      adService = AdService(storage: storage);
    });

    test('defaults to simulated mode', () {
      expect(adService.currentMode, AdMode.simulated);
    });

    test('reflects stored adMode correctly', () async {
      await storage.setAdMode('real');
      expect(adService.currentMode, AdMode.real);

      await storage.setAdMode('disabled');
      expect(adService.currentMode, AdMode.disabled);
    });

    test('contains correct static official AdMob test keys', () {
      expect(AdService.androidBannerUnitId, isNotEmpty);
      expect(AdService.iosBannerUnitId, isNotEmpty);
      expect(AdService.androidInterstitialUnitId, isNotEmpty);
      expect(AdService.iosInterstitialUnitId, isNotEmpty);
    });

    test('showInterstitialAd executes onAdClosed immediately when disabled', () {
      var callbackCalled = false;

      // Set to disabled mode
      storage.setAdMode('disabled');
      expect(adService.currentMode, AdMode.disabled);

      adService.showInterstitialAd(
        context: null,
        onAdClosed: () {
          callbackCalled = true;
        },
      );

      expect(callbackCalled, isTrue);
    });
  });
}
