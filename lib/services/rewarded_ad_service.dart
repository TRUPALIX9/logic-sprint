import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/admob_config.dart';

/// Result of attempting to show a rewarded ad.
class RewardedAdShowResult {
  const RewardedAdShowResult({
    required this.rewardEarned,
    required this.adShown,
  });

  final bool rewardEarned;
  final bool adShown;
}

/// Loads and shows rewarded ads for the global second-life flow.
class RewardedAdService {
  RewardedAdService({bool? useTestAds}) : _useTestAds = useTestAds;

  final bool? _useTestAds;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _rewardEarnedThisShow = false;

  bool get isReady => _rewardedAd != null;

  String get _unitId =>
      AdMobConfig.rewardedUnitId(debug: _useTestAds ?? kDebugMode);

  Future<void> load() async {
    if (_isLoading || isReady) {
      return;
    }
    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd?.dispose();
            _rewardedAd = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (_) {
            _rewardedAd = null;
            _isLoading = false;
          },
        ),
      );
    } catch (_) {
      _rewardedAd = null;
      _isLoading = false;
    }
  }

  void _scheduleReload() {
    unawaited(load().catchError((_) {}));
  }

  Future<RewardedAdShowResult> show({VoidCallback? onAdUnavailable}) async {
    final ad = _rewardedAd;
    if (ad == null) {
      onAdUnavailable?.call();
      _scheduleReload();
      return const RewardedAdShowResult(rewardEarned: false, adShown: false);
    }

    _rewardEarnedThisShow = false;
    final completer = Completer<RewardedAdShowResult>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) {
          completer.complete(
            RewardedAdShowResult(
              rewardEarned: _rewardEarnedThisShow,
              adShown: true,
            ),
          );
        }
        _scheduleReload();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        failedAd.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) {
          completer.complete(
            const RewardedAdShowResult(rewardEarned: false, adShown: false),
          );
        }
        _scheduleReload();
      },
    );

    await ad.show(
      onUserEarnedReward: (_, _) {
        _rewardEarnedThisShow = true;
      },
    );

    if (!completer.isCompleted) {
      return const RewardedAdShowResult(rewardEarned: false, adShown: true);
    }
    return completer.future;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isLoading = false;
  }
}
