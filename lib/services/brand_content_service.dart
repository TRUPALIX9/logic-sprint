import 'package:flutter/services.dart';

import '../core/brand/brand_assets.dart';

/// Loads markdown copy shipped with the brand kit.
abstract final class BrandContentService {
  static Future<String> loadPrivacyPolicy() =>
      rootBundle.loadString(BrandAssets.privacyPolicy);

  static Future<String> loadStoreListing() =>
      rootBundle.loadString(BrandAssets.storeListing);
}
