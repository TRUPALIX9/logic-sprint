import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_model.dart';

/// All-time leaderboard row for one player on one game.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.gameType,
    required this.score,
    required this.level,
    required this.usedSecondLife,
    this.updatedAt,
  });

  final String playerId;
  final String playerName;
  final GameType gameType;
  final int score;
  final int level;
  final bool usedSecondLife;
  final DateTime? updatedAt;

  factory LeaderboardEntry.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final gameKey = data['gameType'] as String? ?? '';
    return LeaderboardEntry(
      playerId: data['playerId'] as String? ?? docId,
      playerName: data['playerName'] as String? ?? 'Player',
      gameType: GameTypeLeaderboardX.fromLeaderboardKey(gameKey),
      score: (data['score'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 0,
      usedSecondLife: data['usedSecondLife'] as bool? ?? false,
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'gameType': gameType.leaderboardKey,
      'score': score,
      'level': level,
      'usedSecondLife': usedSecondLife,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId'] as String? ?? '',
      playerName: json['playerName'] as String? ?? 'Player',
      gameType: GameTypeLeaderboardX.fromLeaderboardKey(
        json['gameType'] as String? ?? '',
      ),
      score: (json['score'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      usedSecondLife: json['usedSecondLife'] as bool? ?? false,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

extension GameTypeLeaderboardX on GameType {
  static GameType fromLeaderboardKey(String key) {
    switch (key) {
      case 'quick_math':
        return GameType.quickMath;
      case 'color_sequence':
        return GameType.colorSequence;
      case 'emoji_match':
        return GameType.emojiMatch;
      case 'pattern_lock':
        return GameType.patternLock;
      case 'launch_rocket':
        return GameType.launchRocket;
      case 'true_false':
        return GameType.trueFalse;
      default:
        return GameType.quickMath;
    }
  }

  String get leaderboardKey {
    switch (this) {
      case GameType.quickMath:
        return 'quick_math';
      case GameType.colorSequence:
        return 'color_sequence';
      case GameType.emojiMatch:
        return 'emoji_match';
      case GameType.patternLock:
        return 'pattern_lock';
      case GameType.launchRocket:
        return 'launch_rocket';
      case GameType.trueFalse:
        return 'true_false';
    }
  }
}
