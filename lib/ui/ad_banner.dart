import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ads.dart';

/// AdMob banner. Takes no space until consent is resolved and an ad loads.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  Ads? _ads;
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.read<Ads>();
    if (!identical(ads, _ads)) {
      _ads?.ready.removeListener(_loadIfReady);
      _ads = ads..ready.addListener(_loadIfReady);
      _loadIfReady();
    }
  }

  void _loadIfReady() {
    final ads = _ads;
    if (ads == null ||
        !ads.ready.value ||
        ads.bannerUnitId.isEmpty ||
        _banner != null) {
      return;
    }
    _banner = BannerAd(
      adUnitId: ads.bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _loaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBanner: failed to load: ${error.message}');
          ad.dispose();
          _banner = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ads?.ready.removeListener(_loadIfReady);
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
