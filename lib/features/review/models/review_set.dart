class ReviewSet {
  final String id;
  final String title;
  final List<String> itemIds;
  final int count;
  final int createdAt;
  final int updatedAt;
  final int due;
  final int reps;
  final int lastRating;

  const ReviewSet({
    required this.id,
    required this.title,
    required this.itemIds,
    required this.count,
    required this.createdAt,
    required this.updatedAt,
    required this.due,
    required this.reps,
    required this.lastRating,
  });

  ReviewSet copyWith({
    String? id,
    String? title,
    List<String>? itemIds,
    int? count,
    int? createdAt,
    int? updatedAt,
    int? due,
    int? reps,
    int? lastRating,
  }) {
    return ReviewSet(
      id: id ?? this.id,
      title: title ?? this.title,
      itemIds: itemIds ?? this.itemIds,
      count: count ?? this.count,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      due: due ?? this.due,
      reps: reps ?? this.reps,
      lastRating: lastRating ?? this.lastRating,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'itemIds': itemIds,
        'count': count,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'due': due,
        'reps': reps,
        'lastRating': lastRating,
      };

  factory ReviewSet.fromMap(Map<String, dynamic> m) {
    final rawIds = m['itemIds'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final e in rawIds) {
        if (e == null) continue;
        ids.add(e.toString());
      }
    }
    return ReviewSet(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      itemIds: ids,
      count: _asInt(m['count']),
      createdAt: _asInt(m['createdAt']),
      updatedAt: _asInt(m['updatedAt']),
      due: _asInt(m['due']),
      reps: _asInt(m['reps']),
      lastRating: _asInt(m['lastRating']),
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

