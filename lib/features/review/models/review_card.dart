class ReviewCard {
  final String id;
  final String sentence;
  final String meaning;
  final String? setId; // 세트 식별자(옵션)
  final int createdAt; // epoch millis
  final int updatedAt; // epoch millis
  final int due; // epoch millis
  final int reps;
  final int lapses;
  final double stability;
  final double difficulty;
  final int lastRating; // e.g., 2=Good

  const ReviewCard({
    required this.id,
    required this.sentence,
    required this.meaning,
    this.setId,
    required this.createdAt,
    required this.updatedAt,
    required this.due,
    required this.reps,
    required this.lapses,
    required this.stability,
    required this.difficulty,
    required this.lastRating,
  });

  ReviewCard copyWith({
    String? id,
    String? sentence,
    String? meaning,
    String? setId,
    int? createdAt,
    int? updatedAt,
    int? due,
    int? reps,
    int? lapses,
    double? stability,
    double? difficulty,
    int? lastRating,
  }) {
    return ReviewCard(
      id: id ?? this.id,
      sentence: sentence ?? this.sentence,
      meaning: meaning ?? this.meaning,
      setId: setId ?? this.setId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      due: due ?? this.due,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      lastRating: lastRating ?? this.lastRating,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sentence': sentence,
        'meaning': meaning,
        'setId': setId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'due': due,
        'reps': reps,
        'lapses': lapses,
        'stability': stability,
        'difficulty': difficulty,
        'lastRating': lastRating,
      };

  factory ReviewCard.fromMap(Map<String, dynamic> m) {
    return ReviewCard(
      id: (m['id'] ?? '').toString(),
      sentence: (m['sentence'] ?? '').toString(),
      meaning: (m['meaning'] ?? '').toString(),
      setId: (m['setId'] == null || m['setId'].toString().isEmpty) ? null : m['setId'].toString(),
      createdAt: _asInt(m['createdAt']),
      updatedAt: _asInt(m['updatedAt']),
      due: _asInt(m['due']),
      reps: _asInt(m['reps']),
      lapses: _asInt(m['lapses']),
      stability: _asDouble(m['stability']),
      difficulty: _asDouble(m['difficulty']),
      lastRating: _asInt(m['lastRating']),
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
