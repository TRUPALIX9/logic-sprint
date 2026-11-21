import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/config.dart';
import '../models/profile_stats.dart';
import '../screens/profile/share_card.dart';
import 'share_image.dart';

/// Under the Share button: the link is copied as well, because Instagram
/// and Snapchat drop the shared text (Instagram can't take a link sticker
/// from another app, so the player pastes it).
const linkCopiedNote =
    'The link is copied too: paste it as a link sticker '
    'on Instagram or Snapchat.';

/// Phase 1: one system share sheet with the PNG and [AppConfig.shareText];
/// the player picks the app there (Instagram Story/Post/Message, Snapchat,
/// WhatsApp, Messages, save…).
class StatsSharer {
  const StatsSharer({this.render = renderPng, this.share = _systemShare});

  /// Swappable for tests (no platform channel there).
  final Future<Uint8List> Function(
    Widget child, {
    required Size size,
    required double pixelRatio,
  })
  render;
  final Future<void> Function(ShareParams params) share;

  static Future<void> _systemShare(ShareParams params) =>
      SharePlus.instance.share(params);

  /// The 1080 × 1920 PNG.
  Future<Uint8List> image(ProfileStats stats) => render(
    ShareCard(stats: stats),
    size: ShareCard.size,
    pixelRatio: ShareCard.pixelRatio,
  );

  /// Renders the image, copies the link and opens the share sheet.
  /// [origin] anchors the sheet on iPad.
  Future<void> send(ProfileStats stats, {Rect? origin}) async {
    final png = await image(stats);
    await Clipboard.setData(const ClipboardData(text: AppConfig.shareUrl));
    // TODO(snap-phase-2): Snapchat Creative Kit. Send the PNG with
    // attachmentUrl = AppConfig.shareUrl so the Snap carries a tappable
    // link (Snap only accepts a direct link, no redirects; needs Snap Kit
    // app review). Keep this sheet as the fallback.
    // TODO(instagram-phase-2): Instagram Stories direct share needs a Meta
    // app ID; same fallback.
    await share(
      ShareParams(
        text: AppConfig.shareText,
        files: [
          XFile.fromData(png, mimeType: 'image/png', name: 'logicsprint.png'),
        ],
        fileNameOverrides: ['logicsprint.png'],
        sharePositionOrigin: origin,
      ),
    );
  }
}
