/// On-device logs: which ads were shown and every name the player used.
/// Kept only on this phone; nothing here is sent anywhere.
library;

/// Where an ad was shown.
enum AdKind {
  /// Rewarded ad to revive a run.
  revive,

  /// Rewarded ad to earn a heart (Result screen, Hearts sheet).
  heart,

  /// Rewarded interstitial behind the Ranks "Refresh".
  refresh,

  /// A banner impression.
  banner,
}

/// How a shown ad ended.
enum AdOutcome {
  /// Watched through: the reward was given.
  rewarded,

  /// Shown but closed before the reward.
  noReward,

  /// A banner was seen (banners have no reward).
  shown,
}

class AdEvent {
  const AdEvent({required this.kind, required this.outcome, required this.at});

  final AdKind kind;
  final AdOutcome outcome;
  final DateTime at;

  /// Compact row: [kind, outcome, at ms].
  List<Object> toRow() => [kind.name, outcome.name, at.millisecondsSinceEpoch];

  static AdEvent? fromRow(Object? row) {
    if (row is! List || row.length < 3) {
      return null;
    }
    final kind = AdKind.values.where((k) => k.name == row[0]).firstOrNull;
    final outcome = AdOutcome.values.where((o) => o.name == row[1]).firstOrNull;
    final at = row[2];
    if (kind == null || outcome == null || at is! num) {
      return null;
    }
    return AdEvent(
      kind: kind,
      outcome: outcome,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}

/// One name the player took (with its 4-digit code) and when.
class NameUse {
  const NameUse({required this.name, required this.tag, required this.at});

  final String name;
  final int tag;
  final DateTime at;

  /// Compact row: [name, tag, at ms].
  List<Object> toRow() => [name, tag, at.millisecondsSinceEpoch];

  static NameUse? fromRow(Object? row) {
    if (row is! List || row.length < 3) {
      return null;
    }
    final (name, tag, at) = (row[0], row[1], row[2]);
    if (name is! String || tag is! num || at is! num) {
      return null;
    }
    return NameUse(
      name: name,
      tag: tag.toInt(),
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}
