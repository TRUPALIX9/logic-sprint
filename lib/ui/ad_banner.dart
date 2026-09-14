import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ads.dart';

/// Full-width (anchored adaptive) AdMob banner. Takes no space until ads are
/// allowed; then reserves the banner's height before it loads, so nothing
/// shifts under the player's finger. Collapses again if no ad loads.
///
/// Never put this on a screen where the player is tapping continuously
/// (game screens): AdMob treats that as an accidental-click placement.
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final EdgeInsetsGeometry padding;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  Ads? _ads;
  BannerAd? _banner;
  AdSize? _size;
  int _width = 0;
  bool _loaded = false;
  bool _requesting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _width = MediaQuery.sizeOf(context).width.truncate();
    final ads = context.read<Ads>();
    if (!identical(ads, _ads)) {
      _ads?.ready.removeListener(_loadIfReady);
      _ads = ads..ready.addListener(_loadIfReady);
      _loadIfReady();
    }
  }

  Future<void> _loadIfReady() async {
    final ads = _ads;
    if (ads == null ||
        !ads.ready.value ||
        ads.bannerUnitId.isEmpty ||
        _banner != null ||
        _requesting ||
        _width <= 0) {
      return;
    }
    _requesting = true;
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          _width,
        ) ??
        AdSize.banner;
    _requesting = false;
    if (!mounted) {
      return;
    }
    setState(() => _size = size);
    _banner = BannerAd(
      adUnitId: ads.bannerUnitId,
      request: const AdRequest(),
      size: size,
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
          if (mounted) {
            setState(() {
              _size = null;
              _loaded = false;
            });
          }
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
    final size = _size;
    final banner = _banner;
    if (size == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.padding,
      child: Center(
        child: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: _loaded && banner != null ? AdWidget(ad: banner) : null,
        ),
      ),
    );
  }
}
