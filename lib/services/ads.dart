import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob banner + rewarded ads ("extra life" revive, and "Refresh now" on
/// the Ranks tab), gated behind Google UMP consent.
///
/// Unit IDs come from `--dart-define-from-file=config/admob.json`
/// (template: config/admob.example.json). Debug and profile builds fall back
/// to Google's test IDs; a release build without an ID shows no such ad.
/// `ADMOB_REFRESH_REWARDED_ID` is optional: without it the Ranks refresh uses
/// the revive unit (and the same preloaded ad).
class Ads {
  Ads();

  static const _bannerId = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _rewardedId = String.fromEnvironment('ADMOB_REWARDED_ID');
  static const _refreshRewardedId = String.fromEnvironment(
    'ADMOB_REFRESH_REWARDED_ID',
  );

  // Official Google test unit IDs.
  static const androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

  /// True once consent allows ad requests and the SDK is initialized.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// True when users must be offered a way to change consent (EEA/UK/CH).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  late final _RewardedSlot _revive = _RewardedSlot(rewardedUnitId);

  // One unit → one shared slot, so the same ad isn't preloaded twice.
  late final _RewardedSlot _refresh = refreshRewardedUnitId == rewardedUnitId
      ? _revive
      : _RewardedSlot(refreshRewardedUnitId);

  /// True while a rewarded ad is loaded and can be offered as a revive.
  ValueNotifier<bool> get rewardedReady => _revive.loaded;

  /// True while a rewarded ad is loaded for the Ranks "Refresh now".
  ValueNotifier<bool> get refreshRewardedReady => _refresh.loaded;

  String get bannerUnitId =>
      _resolve(_bannerId, androidTestBanner, iosTestBanner);
  String get rewardedUnitId =>
      _resolve(_rewardedId, androidTestRewarded, iosTestRewarded);

  /// The Ranks refresh unit, or the revive unit when none is configured.
  String get refreshRewardedUnitId =>
      _refreshRewardedId.isNotEmpty ? _refreshRewardedId : rewardedUnitId;

  bool get isConfigured =>
      bannerUnitId.isNotEmpty ||
      rewardedUnitId.isNotEmpty ||
      refreshRewardedUnitId.isNotEmpty;

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

  /// Loads a rewarded ad if none is ready (call when a run starts).
  void preloadRewarded() {
    if (ready.value) {
      _revive.load();
    }
  }

  /// Shows the rewarded ad. Exactly one callback runs: [onReward] if the
  /// user watched it through, otherwise [onDone].
  void showRewarded({
    required VoidCallback onReward,
    required VoidCallback onDone,
  }) => _revive.show(onReward: onReward, onDone: onDone);

  /// Loads the Ranks refresh ad if none is ready (call when Ranks opens).
  void preloadRefreshRewarded() {
    if (ready.value) {
      _refresh.load();
    }
  }

  /// Shows the Ranks refresh ad; same contract as [showRewarded].
  void showRefreshRewarded({
    required VoidCallback onReward,
    required VoidCallback onDone,
  }) => _refresh.show(onReward: onReward, onDone: onDone);

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
    // The refresh slot (if separate) loads when Ranks opens.
    _revive.load();
  }
}

/// One preloaded [RewardedAd] for one ad unit; reloads after each show.
class _RewardedSlot {
  _RewardedSlot(this.unitId);

  final String unitId;
  final ValueNotifier<bool> loaded = ValueNotifier(false);
  RewardedAd? _ad;
  bool _loading = false;

  void load() {
    if (unitId.isEmpty || _loading || _ad != null) {
      return;
    }
    _loading = true;
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ad = ad;
          loaded.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ads: rewarded ($unitId) failed to load: $error');
          _loading = false;
          _ad = null;
          loaded.value = false;
        },
      ),
    );
  }

  void show({required VoidCallback onReward, required VoidCallback onDone}) {
    final ad = _ad;
    if (ad == null) {
      onDone();
      return;
    }
    _ad = null;
    loaded.value = false;
    var earned = false;
    void close() {
      ad.dispose();
      earned ? onReward() : onDone();
      load();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => close(),
      onAdFailedToShowFullScreenContent: (_, _) => close(),
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
  }
}
