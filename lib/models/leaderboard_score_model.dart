class LeaderboardScoreModel {
  const LeaderboardScoreModel({
    required this.id,
    required this.playerName,
    required this.score,
    required this.gameType,
    required this.difficulty,
    required this.createdAt,
    required this.appVersion,
  });

  final String id;
  final String playerName;
  final int score;
  final String gameType;
  final String difficulty;
  final DateTime? createdAt;
  final String appVersion;

  factory LeaderboardScoreModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    DateTime? createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    }

    return LeaderboardScoreModel(
      id: (json['id'] ?? '').toString(),
      playerName: (json['playerName'] ?? json['player_name'] ?? 'Player') as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      gameType: (json['gameType'] ?? json['game_type'] ?? '') as String,
      difficulty: (json['difficulty'] ?? json['difficulty'] ?? '') as String,
      createdAt: createdAt,
      appVersion: (json['appVersion'] ?? json['app_version'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerName': playerName,
      'score': score,
      'gameType': gameType,
      'difficulty': difficulty,
      'createdAt': createdAt?.toIso8601String(),
      'appVersion': appVersion,
    };
  }

  String get gameTypeLabel {
    switch (gameType) {
      case 'rocketLaunch':
        return 'Rocket Launch';
      case 'memoryLane':
        return 'Memory Lane';
      case 'quickMath':
        return 'Quick Math';
      case 'colorSequence':
        return 'Color Sequence';
      case 'numberSequence':
        return 'Color Sequence';
      case 'trueFalse':
        return 'True or False';
      default:
        return gameType;
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return difficulty;
    }
  }
}
