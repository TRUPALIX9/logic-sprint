import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../core/brand/brand_palette.dart';
import '../services/ad_service.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  void _loadAd() {
    final adService = context.read<AdService>();
    if (adService.currentMode != AdMode.real) {
      _bannerAd?.dispose();
      _bannerAd = null;
      setState(() {
        _isLoaded = false;
      });
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: adService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdBannerWidget: AdMob failed to load: ${err.message}. Falling back to simulated banner.');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdService>();
    final mode = adService.currentMode;

    if (mode == AdMode.disabled) {
      return const SizedBox.shrink();
    }

    if (mode == AdMode.real && _isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Fallback to beautiful simulated banner if in simulated mode or if real loading failed
    return _buildSimulatedBanner(context);
  }

  Widget _buildSimulatedBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            BrandPalette.primaryNavy,
            BrandPalette.electricBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showPromoDetails(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Ad Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BrandPalette.energyOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AD',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Ad Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Unlock Sprint Premium!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero Ads, offline database, and more games.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action CTA Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Try Free',
                    style: TextStyle(
                      color: BrandPalette.primaryNavy,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPromoDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('LogicSprint Premium'),
          content: const Text(
            'Go premium today to support independent brain-training game development!\n\n'
            'Includes:\n'
            '• 100% Ad-Free Experience\n'
            '• Unlimited Global Leaderboard submissions\n'
            '• Advanced personal offline analytics & graphs\n'
            '• Premium custom color palettes & app icons',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('LogicSprint Premium is simulated. Thank you for your support!'),
                  ),
                );
              },
              child: const Text('Upgrade - \$1.99'),
            ),
          ],
        );
      },
    );
  }
}
