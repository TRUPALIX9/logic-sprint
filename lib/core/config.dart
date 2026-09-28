abstract final class AppConfig {
  // Scoring shared by every game.
  static const pointsPerCorrect = 10;
  static const streakBonusEvery = 5;
  static const streakBonusPoints = 20;

  // Revives (rewarded ad or a heart). All revived runs are ranked.
  static const maxRevivesPerRun = 3;
  // Below this score a down run just ends; no revive is offered.
  static const reviveMinScore = 50;
  // The revive offer auto-declines (ends the run) after this long.
  static const reviveOfferSeconds = 5;

  // Global leaderboard (Supabase). The publishable key is safe to ship:
  // row-level security in supabase/schema.sql makes tables read-only, and
  // writes go through functions that only touch the caller's own rows.
  static const supabaseUrl = 'https://axucnwnzuhdsiggqyjqf.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_dzJkARQ59BSHuvJIlhnoTg_4NI5kWo0';
  static const leaderboardLimit = 10;
  // Boards update for everyone once a day, on the first look after 00:00
  // UTC; a player's own new best shows on their board straight away.
  // "Refresh ▶" (a rewarded interstitial) fetches early, then waits this.
  static const leaderboardRefreshCooldown = Duration(minutes: 30);
  // Rank-change reveal on the Ranks tab.
  static const leaderboardRowStagger = Duration(milliseconds: 60);
  static const leaderboardRowMove = Duration(milliseconds: 700);
  static const maxPlayerNameLength = 20;

  // The app's page on the developer site (also hosts privacy + app-ads.txt).
  static const websiteUrl = 'https://logicsprint.trupalpatel.com';
  static const supportEmail = 'trupal.work@gmail.com';
}

abstract final class PlayerName {
  static final _allowed = RegExp(r'^[A-Za-z0-9 _\-]+$');

  /// Error message, or null when [raw] is a valid display name.
  static String? validate(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.isEmpty) {
      return 'Enter a display name.';
    }
    if (name.length > AppConfig.maxPlayerNameLength) {
      return 'Use ${AppConfig.maxPlayerNameLength} characters or fewer.';
    }
    if (!_allowed.hasMatch(name)) {
      return 'Letters, numbers, spaces, _ and - only.';
    }
    return null;
  }
}
