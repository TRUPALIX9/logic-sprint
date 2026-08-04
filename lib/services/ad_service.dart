import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'local_storage_service.dart';

enum AdMode {
  simulated,
  real,
  disabled;

  String get displayName {
    switch (this) {
      case AdMode.simulated:
        return 'Simulated (In-App)';
      case AdMode.real:
        return 'Real AdMob Ads';
      case AdMode.disabled:
        return 'Disabled (No Ads)';
    }
  }

  static AdMode fromString(String value) {
    return AdMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AdMode.simulated,
    );
  }
}

class AdService {
  AdService({required LocalStorageService storage}) : _storage = storage;

  final LocalStorageService _storage;
  bool _sdkInitialized = false;

  // Official Test Ad Unit IDs from Google
  static const String androidBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const String androidInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String iosInterstitialUnitId = 'ca-app-pub-3940256099942544/4411468910';

  AdMode get currentMode {
    final modeStr = _storage.getAdMode();
    return AdMode.fromString(modeStr);
  }

  String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidBannerUnitId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosBannerUnitId;
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidInterstitialUnitId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosInterstitialUnitId;
    }
    return '';
  }

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    if (currentMode == AdMode.disabled) {
      return;
    }
    try {
      // Safely initialize the SDK. Catch any potential platform channel crashes.
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    } on Object catch (e) {
      debugPrint('AdService: Failed to initialize Google Mobile Ads: $e');
      _sdkInitialized = false;
    }
  }

  /// Helper to trigger interstitial display on completing a game
  void showInterstitialAd({
    required BuildContext? context,
    required VoidCallback onAdClosed,
  }) {
    final mode = currentMode;
    if (mode == AdMode.disabled) {
      onAdClosed();
      return;
    }

    if (mode == AdMode.simulated) {
      if (context != null) {
        _showSimulatedInterstitial(context, onAdClosed);
      } else {
        onAdClosed();
      }
      return;
    }

    // Real AdMob mode
    if (!_sdkInitialized) {
      debugPrint('AdService: AdMob SDK not initialized, falling back to simulated ad.');
      if (context != null) {
        _showSimulatedInterstitial(context, onAdClosed);
      } else {
        onAdClosed();
      }
      return;
    }

    if (context != null) {
      _loadAndShowRealInterstitial(context, onAdClosed);
    } else {
      onAdClosed();
    }
  }

  void _loadAndShowRealInterstitial(BuildContext context, VoidCallback onAdClosed) {
    // Show a small loader to wait for the ad to load, or show immediate simulated ad if taking too long
    var adLoaded = false;
    InterstitialAd? realAd;

    // We'll set a timeout for the ad load
    Future.delayed(const Duration(seconds: 2), () {
      if (!adLoaded) {
        debugPrint('AdService: AdMob load timed out. Falling back to simulated ad.');
        if (context.mounted) {
          _showSimulatedInterstitial(context, onAdClosed);
        } else {
          onAdClosed();
        }
      }
    });

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          adLoaded = true;
          realAd = ad;
          realAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdClosed();
            },
          );
          realAd!.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdService: Failed to load real interstitial: ${error.message}. Falling back to simulated ad.');
          if (!adLoaded) {
            adLoaded = true; // prevent double trigger
            _showSimulatedInterstitial(context, onAdClosed);
          }
        },
      ),
    );
  }

  void _showSimulatedInterstitial(BuildContext context, VoidCallback onAdClosed) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SimulatedInterstitialDialog(onAdClosed: onAdClosed);
      },
    );
  }
}

class _SimulatedInterstitialDialog extends StatefulWidget {
  const _SimulatedInterstitialDialog({required this.onAdClosed});

  final VoidCallback onAdClosed;

  @override
  State<_SimulatedInterstitialDialog> createState() => _SimulatedInterstitialDialogState();
}

class _SimulatedInterstitialDialogState extends State<_SimulatedInterstitialDialog> {
  int _secondsRemaining = 3;
  late final Stream<int> _timerStream;

  @override
  void initState() {
    super.initState();
    _timerStream = Stream<int>.periodic(const Duration(seconds: 1), (count) => 2 - count).take(3);
    _timerStream.listen((val) {
      if (mounted) {
        setState(() {
          _secondsRemaining = val;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return PopScope(
      canPop: false, // Prevent physical back button escape
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.cardTheme.color,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ADVERTISEMENT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _secondsRemaining > 0
                      ? Text(
                          'Skip in ${_secondsRemaining}s',
                          style: theme.textTheme.bodySmall,
                        )
                      : TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onAdClosed();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Close Ad'),
                        ),
                ],
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'LogicSprint Premium',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Support LogicSprint and unlock offline metrics, limitless custom leaderboard profiles, and custom branding modes!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('LogicSprint Premium is a mock subscription! Thank you for supporting us.')),
                  );
                  Navigator.of(context).pop();
                  widget.onAdClosed();
                },
                child: const Text('Unlock Premium - \$1.99'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _secondsRemaining > 0
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onAdClosed();
                      },
                child: Text(
                  _secondsRemaining > 0 ? 'Loading skip action...' : 'Dismiss ad',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
