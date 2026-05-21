abstract final class AppConfig {
  static const String appVersion = '1.0.0';
  static const String leaderboardCollection = 'leaderboardScores';
  static const int leaderboardLimit = 100;
  static const int leaderboardCacheMinutes = 10;
  static const int leaderboardRefreshCooldownSeconds = 60;
  static const int maxDailyLeaderboardSubmissions = 5;
  static const int maxPlayerNameLength = 20;
}
