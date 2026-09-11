abstract final class AppConfig {
  static const roundSeconds = 30;

  // Scoring shared by every game.
  static const pointsPerCorrect = 10;
  static const streakBonusEvery = 5;
  static const streakBonusPoints = 20;

  // Global leaderboard (Supabase). The publishable key is safe to ship;
  // row-level security in supabase/schema.sql limits it to read + insert.
  static const supabaseUrl = 'https://axucnwnzuhdsiggqyjqf.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_dzJkARQ59BSHuvJIlhnoTg_4NI5kWo0';
  static const leaderboardTable = 'leaderboard_scores';
  static const leaderboardLimit = 10;
  static const leaderboardCacheTtl = Duration(minutes: 10);
  static const leaderboardRefreshCooldown = Duration(seconds: 60);
  static const maxDailySubmissions = 5;
  static const maxPlayerNameLength = 20;
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
