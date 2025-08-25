import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/review_card.dart';
import 'review_repository.dart';
import '../scheduler/fsrs_scheduler.dart';

class ReviewRepositoryPrefs implements ReviewRepository {
  static const String _kKey = 'review_cards_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<void> upsertAll(List<ReviewCard> cards) async {
    final p = await _prefs();
    final list = await _loadAllInternal(p);
    final map = {for (final c in list) c.id: c};
    for (final c in cards) {
      map[c.id] = c;
    }
    final encoded = jsonEncode(map.values.map((e) => e.toMap()).toList());
    await p.setString(_kKey, encoded);
  }

  @override
  Future<List<ReviewCard>> fetchAll() async {
    final p = await _prefs();
    return _loadAllInternal(p);
  }

  @override
  Future<List<ReviewCard>> fetchDue({DateTime? now}) async {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final all = await fetchAll();
    return all.where((e) => e.due <= ts).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
  }

  @override
  Future<void> delete(String id) async {
    final p = await _prefs();
    final list = await _loadAllInternal(p);
    final filtered = list.where((e) => e.id != id).toList();
    await p.setString(_kKey, jsonEncode(filtered.map((e) => e.toMap()).toList()));
  }

  @override
  Future<void> updateAfterReview(String id, {required int rating, DateTime? now}) async {
    final p = await _prefs();
    final list = await _loadAllInternal(p);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    ReviewCard updated;
    if (rating == 2) {
      updated = FsrsScheduler.applyGood(list[idx], DateTime.fromMillisecondsSinceEpoch(ts));
    } else {
      updated = list[idx].copyWith(
        reps: list[idx].reps + 1,
        lastRating: rating,
        updatedAt: ts,
      );
    }
    list[idx] = updated;
    await p.setString(_kKey, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  Future<List<ReviewCard>> _loadAllInternal(SharedPreferences p) async {
    final s = p.getString(_kKey);
    if (s == null || s.isEmpty) return <ReviewCard>[];
    try {
      final arr = jsonDecode(s);
      if (arr is List) {
        return arr
            .whereType<Map<String, dynamic>>()
            .map((m) => ReviewCard.fromMap(m))
            .toList();
      }
    } catch (_) {}
    return <ReviewCard>[];
  }
}
