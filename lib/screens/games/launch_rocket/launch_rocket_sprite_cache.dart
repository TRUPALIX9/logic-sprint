import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'launch_rocket_assets.dart';

/// Decoded bitmaps for the Launch Rocket game loop.
class LaunchRocketSpriteCache {
  ui.Image? rocket;
  final List<ui.Image> asteroids = [];

  bool get isReady =>
      rocket != null && asteroids.length == LaunchRocketAssets.asteroids.length;

  Future<void> load() async {
    rocket = await _decodeAsset(LaunchRocketAssets.rocket);
    for (final path in LaunchRocketAssets.asteroids) {
      asteroids.add(await _decodeAsset(path));
    }
  }

  Future<ui.Image> _decodeAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  ui.Image asteroidSprite(int index) {
    return asteroids[index % asteroids.length];
  }

  void dispose() {
    rocket?.dispose();
    rocket = null;
    for (final image in asteroids) {
      image.dispose();
    }
    asteroids.clear();
  }
}
