import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:englishplease/features/review/data/review_set_repository_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('create, fetchDue, update, delete set flow', () async {
    final repo = ReviewSetRepositoryPrefs();
    final now = DateTime(2024, 1, 1, 12);

    final id = await repo.createSet(title: '세트1', itemIds: ['a', 'b', 'c'], now: now);
    expect(id.isNotEmpty, true);

    final due = await repo.fetchDueSets(now: now);
    expect(due.length, 1);
    expect(due.first.id, id);

    await repo.updateSetAfterReview(id, rating: 2, now: now);
    final after = await repo.fetchAllSets();
    final s = after.firstWhere((e) => e.id == id);
    // Good(2) 적용 후 reps=1, due=다음날 00:00
    expect(s.reps, 1);
    expect(s.due, DateTime(2024, 1, 2, 0).millisecondsSinceEpoch);

    await repo.deleteSet(id);
    final all = await repo.fetchAllSets();
    expect(all.where((e) => e.id == id).isEmpty, true);
  });
}
