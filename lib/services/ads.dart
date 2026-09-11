import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob banner + interstitial, gated behind Google UMP consent.
///
/// Unit IDs come from `--dart-define-from-file=config/admob.json`
/// (template: config/admob.example.json). Debug and profile builds fall back
/// to Google's test IDs; a release build without IDs shows no ads.
class Ads {
  Ads({this.roundsPerInterstitial = 2});

  static const _bannerId = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _interstitialId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );

  // Official Google test unit IDs.
  static const androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const iosTestInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  final int roundsPerInterstitial;

  /// True once consent allows ad requests and the SDK is initialized.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// True when users must be offered a way to change consent (EEA/UK/CH).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  InterstitialAd? _interstitial;
  int _roundsSinceInterstitial = 0;

  String get bannerUnitId =>
      _resolve(_bannerId, androidTestBanner, iosTestBanner);
  String get interstitialUnitId =>
      _resolve(_interstitialId, androidTestInterstitial, iosTestInterstitial);

  bool get isConfigured =>
      bannerUnitId.isNotEmpty && interstitialUnitId.isNotEmpty;

  static String _resolve(String configured, String android, String ios) {
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kReleaseMode) {
      return '';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => '',
    };
  }

  /// Gathers consent (showing Google's form when required), then starts the
  /// SDK. Call after `runApp`; failures simply leave ads off.
  Future<void> initialize() async {
    if (!isConfigured) {
      return;
    }
    try {
      await _gatherConsent();
      privacyOptionsRequired.value =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      await _startIfAllowed();
    } on Object catch (e) {
      debugPrint('Ads: initialization failed: $e');
    }
  }

  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          debugPrint('Ads: privacy options error: ${error.message}');
        }
      });
      await _startIfAllowed();
    } on Object catch (e) {
      debugPrint('Ads: privacy options failed: $e');
    }
  }

  /// Call when a round ends. Shows a preloaded interstitial every
  /// [roundsPerInterstitial] rounds; [then] always runs exactly once.
  void afterRound(VoidCallback then) {
    _roundsSinceInterstitial++;
    final ad = _interstitial;
    if (ad == null || _roundsSinceInterstitial < roundsPerInterstitial) {
      then();
      return;
    }
    _interstitial = null;
    _roundsSinceInterstitial = 0;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        then();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        then();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    void finish(String? error) {
      if (error != null) {
        debugPrint('Ads: consent error: $error');
      }
      if (!done.isCompleted) {
        done.complete();
      }
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired(
        (error) => finish(error?.message),
      ),
      (error) => finish(error.message),
    );
    return done.future;
  }

  Future<void> _startIfAllowed() async {
    if (ready.value || !await ConsentInformation.instance.canRequestAds()) {
      return;
    }
    await MobileAds.instance.initialize();
    ready.value = true;
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          debugPrint('Ads: interstitial failed to load: ${error.message}');
          _interstitial = null;
        },
      ),
    );
  }
}
