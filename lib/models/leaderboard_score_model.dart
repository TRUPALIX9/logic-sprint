import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory LeaderboardScoreModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['createdAt'];
    return LeaderboardScoreModel(
      id: doc.id,
      playerName: data['playerName'] as String? ?? 'Player',
      score: (data['score'] as num?)?.toInt() ?? 0,
      gameType: data['gameType'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      appVersion: data['appVersion'] as String? ?? '',
    );
  }

  factory LeaderboardScoreModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    }

    return LeaderboardScoreModel(
      id: json['id'] as String? ?? '',
      playerName: json['playerName'] as String? ?? 'Player',
      score: (json['score'] as num?)?.toInt() ?? 0,
      gameType: json['gameType'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      createdAt: createdAt,
      appVersion: json['appVersion'] as String? ?? '',
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
