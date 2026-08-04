import '../../models/game_model.dart';

/// Canonical paths to the production brand kit under [assets/brand/].
///
/// See [assets/brand/docs/README.md] for which file to use in each context.
abstract final class BrandAssets {
  // —— App icons (store + launcher generation) ——
  static const String appIcon1024 = 'assets/brand/icons/app_icon_1024.png';
  static const String appIcon512 = 'assets/brand/icons/app_icon_512.png';
  static const String androidAdaptiveForeground =
      'assets/brand/icons/android/adaptive_icon_foreground.png';
  static const String androidAdaptiveBackground =
      'assets/brand/icons/android/adaptive_icon_background.png';

  // —— In-app logos (original crops — preferred over vector placeholder) ——
  static const String logoMark =
      'assets/brand/logos/png/logo_mark_original_transparent.png';
  static const String lockupOnDark =
      'assets/brand/logos/png/horizontal_lockup_white.png';
  static const String lockupOnLight =
      'assets/brand/logos/png/horizontal_lockup_dark.png';
  static const String lockupTransparent =
      'assets/brand/logos/png/horizontal_lockup_transparent.png';

  // —— Reference / design only ——
  static const String originalIconCrop =
      'assets/brand/logos/png/original_concept_icon_crop.png';
  static const String brandKitMaster =
      'assets/brand/logicsprint/brand_kit_master.png';

  // —— Store (not bundled in UI; paths for docs / CI) ——
  static const String playStoreIcon512 =
      'assets/brand/store/google_play/play_store_icon_512.png';
  static const String playFeatureGraphic =
      'assets/brand/store/google_play/feature_graphic_1024x500.png';

  // —— Copy & tokens ——
  static const String brandTokens = 'assets/brand/tokens/brand_tokens.json';
  static const String privacyPolicy = 'assets/brand/docs/privacy_policy.md';
  static const String storeListing = 'assets/brand/docs/store_listing.md';

  // —— Per-game tiles (add tile.png under games/<id>/ when ready) ——
  static String gameTilePath(GameType type) {
    return 'assets/brand/games/${type.storageKey}/tile.png';
  }

  /// Bundled brand art for game select / home cards until custom tiles exist.
  static String gameListingArt(GameType type) {
    switch (type) {
      case GameType.rocketLaunch:
        return logoMark;
      case GameType.memoryLane:
        return appIcon512;
    }
  }
}
