import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/admob_config.dart';

/// Bottom anchored adaptive banner for the home screen only.
class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @visibleForTesting
  static String unitIdForBuildMode({required bool isDebug}) {
    return AdMobConfig.bannerUnitId(debug: isDebug);
  }

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    await _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;

    if (!mounted) {
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) {
      return;
    }

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) {
      return;
    }

    final ad = BannerAd(
      adUnitId: AdMobBanner.unitIdForBuildMode(isDebug: kDebugMode),
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );

    await ad.load();
    if (!mounted) {
      await ad.dispose();
      return;
    }

    setState(() => _bannerAd = ad);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_isLoaded || ad == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
