import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:englishplease/features/review/models/review_card.dart';
import 'package:englishplease/features/review/data/review_repository_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('upsert, fetchAll, fetchDue, updateAfterReview, delete flow', () async {
    final repo = ReviewRepositoryPrefs();
    final now = DateTime(2024, 1, 1, 12, 0, 0);
    final past = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final future = now.add(const Duration(days: 2)).millisecondsSinceEpoch;
    final ts = now.millisecondsSinceEpoch;

    final a = ReviewCard(
      id: 'a',
      sentence: 'This is A.',
      meaning: 'A다',
      createdAt: ts,
      updatedAt: ts,
      due: past,
      reps: 0,
      lapses: 0,
      stability: 0.0,
      difficulty: 0.0,
      lastRating: 0,
    );
    final b = ReviewCard(
      id: 'b',
      sentence: 'This is B.',
      meaning: 'B다',
      createdAt: ts,
      updatedAt: ts,
      due: future,
      reps: 1,
      lapses: 0,
      stability: 0.0,
      difficulty: 0.0,
      lastRating: 2,
    );

    await repo.upsertAll([a, b]);

    final all = await repo.fetchAll();
    expect(all.length, 2);

    final due = await repo.fetchDue(now: now);
    expect(due.length, 1);
    expect(due.first.id, 'a');

    await repo.updateAfterReview('a', rating: 2, now: now);
    final refreshed = await repo.fetchAll();
    final a2 = refreshed.firstWhere((e) => e.id == 'a');
    expect(a2.reps, 1);
    expect(a2.lastRating, 2);
    // FSRS Good 적용: reps=0 -> 1이 되며 due는 다음날 00:00으로 설정
    expect(
      DateTime.fromMillisecondsSinceEpoch(a2.due),
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );

    await repo.delete('a');
    final all2 = await repo.fetchAll();
    expect(all2.length, 1);
    expect(all2.first.id, 'b');
  });
}
