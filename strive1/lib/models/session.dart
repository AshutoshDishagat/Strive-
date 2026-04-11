class Session {
  final int? id;
  final String? userId; // specific
  final String startTime;
  final int durationSeconds;
  final double engagementScore;
  final String? studyMode; // readingBook

  Session({
    this.id,
    this.userId,
    required this.startTime,
    required this.durationSeconds,
    required this.engagementScore,
    this.studyMode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime,
      'duration_seconds': durationSeconds,
      'engagement_score': engagementScore,
      'study_mode': studyMode,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      userId: map['user_id'],
      startTime: map['start_time'],
      durationSeconds: map['duration_seconds'],
      engagementScore: map['engagement_score'],
      studyMode: map['study_mode'],
    );
  }
}
