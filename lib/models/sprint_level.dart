/// The Sprint Score gauge's bands, left (dim end) to right (bright end).
/// Every band is drawn, lit up to the player's band, so the
/// player sees the colours they could reach. [upper] is the worst
/// "top X%" that still falls in the band.
enum SprintBand {
  /// Top 50–100%.
  top100(100),

  /// Top 25–50%.
  top50(50),

  /// Top 10–25%.
  top25(25),

  /// Top 5–10%.
  top10(10),

  /// Top 0–5%.
  top5(5);

  const SprintBand(this.upper);

  final int upper;

  /// Best "top X%" still outside this band (0 for the last band).
  int get lower => index + 1 < values.length ? values[index + 1].upper : 0;
}

/// Where a "top X%" Sprint Score sits on the gauge. Pure Dart so the maths
/// is tested apart from the painter.
class SprintLevel {
  const SprintLevel(this.top);

  /// The rank is shown in every band, Top 1% to Top 100%. Only a player
  /// with no score yet sees the dim gauge and "Play more games to get your score".
  static const showTopPercentAtMost = 100;

  /// "Top X percent" (1–100), or null with no score yet (no runs).
  final int? top;

  /// The rank is shown.
  bool get ranked {
    final top = _top;
    return top != null && top <= showTopPercentAtMost;
  }

  int? get _top => top?.clamp(1, 100);

  /// The band the score falls in; null when the rank isn't shown.
  SprintBand? get band {
    final top = _top;
    if (top == null || !ranked) {
      return null;
    }
    return SprintBand.values.lastWhere((b) => top <= b.upper);
  }

  /// "Top 7%", never a raw number; null when the rank isn't shown.
  String? get label => ranked ? 'Top $_top%' : null;

  /// Fill end along the whole arc, 0–1 (0 when the rank isn't shown).
  /// Each band is one fifth of the arc; a score on a band's worse edge sits
  /// at its middle and better scores move on toward its end, so a Top 5%
  /// lights half the gold band.
  double get position {
    final top = _top;
    final b = band;
    if (top == null || b == null) {
      return 0;
    }
    final within = 0.5 + 0.5 * (b.upper - top) / (b.upper - b.lower);
    return (b.index + within) / SprintBand.values.length;
  }
}
