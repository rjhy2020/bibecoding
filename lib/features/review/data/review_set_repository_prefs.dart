import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/review_set.dart';
import '../utils/review_id.dart';
import 'review_set_repository.dart';
import '../../review/scheduler/fsrs_scheduler.dart';
import 'package:englishplease/config/app_config.dart';

class ReviewSetRepositoryPrefs implements ReviewSetRepository {
  static const String _kKey = 'review_sets_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<String> createSet({required String title, required List<String> itemIds, DateTime? now}) async {
    final p = await _prefs();
    final list = await _loadAll(p);
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final id = makeReviewSetIdForItems(itemIds);

    final exists = list.indexWhere((e) => e.id == id);
    if (exists >= 0) {
      // 이미 존재하면 updatedAt만 갱신
      final updated = list[exists].copyWith(updatedAt: ts);
      list[exists] = updated;
      await _saveAll(p, list);
      return id;
    }

    final dueTs = AppConfig.immediateReviewAfterComplete
        ? ts
        : FsrsScheduler.dueAtStartOfDayPlusDays(now ?? DateTime.now(), 1);

    final set = ReviewSet(
      id: id,
      title: title,
      itemIds: itemIds,
      count: itemIds.length,
      createdAt: ts,
      updatedAt: ts,
      due: dueTs,
      reps: 0,
      lastRating: 0,
    );
    list.add(set);
    await _saveAll(p, list);
    return id;
  }

  @override
  Future<List<ReviewSet>> fetchAllSets() async {
    final p = await _prefs();
    return _loadAll(p);
  }

  @override
  Future<List<ReviewSet>> fetchDueSets({DateTime? now}) async {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final all = await fetchAllSets();
    return all.where((e) => e.due <= ts).toList()..sort((a, b) => a.due.compareTo(b.due));
  }

  @override
  Future<void> deleteSet(String setId) async {
    final p = await _prefs();
    final list = await _loadAll(p);
    final filtered = list.where((e) => e.id != setId).toList();
    await _saveAll(p, filtered);
  }

  @override
  Future<void> updateSetAfterReview(String setId, {required int rating, DateTime? now}) async {
    final p = await _prefs();
    final list = await _loadAll(p);
    final idx = list.indexWhere((e) => e.id == setId);
    if (idx < 0) return;
    final base = list[idx];
    final newReps = base.reps + 1;
    final days = FsrsScheduler.intervalDaysForRating(newReps, rating);
    final dueTs = FsrsScheduler.dueAtStartOfDayPlusDays(now ?? DateTime.now(), days);
    list[idx] = base.copyWith(
      reps: newReps,
      lastRating: rating,
      updatedAt: (now ?? DateTime.now()).millisecondsSinceEpoch,
      due: dueTs,
    );
    await _saveAll(p, list);
  }

  @override
  Future<ReviewSet?> getById(String setId) async {
    final p = await _prefs();
    final list = await _loadAll(p);
    for (final s in list) {
      if (s.id == setId) return s;
    }
    return null;
  }

  Future<List<ReviewSet>> _loadAll(SharedPreferences p) async {
    final s = p.getString(_kKey);
    if (s == null || s.isEmpty) return <ReviewSet>[];
    try {
      final arr = jsonDecode(s);
      if (arr is List) {
        return arr
            .whereType<Map<String, dynamic>>()
            .map((m) => ReviewSet.fromMap(m))
            .toList();
      }
    } catch (_) {}
    return <ReviewSet>[];
  }

  Future<void> _saveAll(SharedPreferences p, List<ReviewSet> list) async {
    await p.setString(_kKey, jsonEncode(list.map((e) => e.toMap()).toList()));
  }
}
