import 'package:flutter/foundation.dart';

/// Central AdMob unit IDs for LogicSprint.
abstract final class AdMobConfig {
  static const String androidAppId = 'ca-app-pub-4460198288175671~6905071306';

  static const String bannerProduction =
      'ca-app-pub-4460198288175671/1111339059';
  static const String bannerTest = 'ca-app-pub-3940256099942544/6300978111';

  static const String rewardedProduction =
      'ca-app-pub-4460198288175671/6542943377';
  static const String rewardedTest = 'ca-app-pub-3940256099942544/5224354917';

  static String bannerUnitId({bool? debug}) {
    final useTest = debug ?? kDebugMode;
    return useTest ? bannerTest : bannerProduction;
  }

  static String rewardedUnitId({bool? debug}) {
    final useTest = debug ?? kDebugMode;
    return useTest ? rewardedTest : rewardedProduction;
  }
}
