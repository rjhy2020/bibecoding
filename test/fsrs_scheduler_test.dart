import 'package:flutter_test/flutter_test.dart';
import 'package:englishplease/features/review/models/review_card.dart';
import 'package:englishplease/features/review/scheduler/fsrs_scheduler.dart';

void main() {
  test('applyGood schedules using increasing intervals', () {
    final now = DateTime(2024, 1, 1);
    var card = ReviewCard(
      id: 'x',
      sentence: 'Hello',
      meaning: '안녕',
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      due: now.millisecondsSinceEpoch,
      reps: 0,
      lapses: 0,
      stability: 0,
      difficulty: 0,
      lastRating: 0,
    );

    card = FsrsScheduler.applyGood(card, now);
    expect(card.reps, 1);
    expect(DateTime.fromMillisecondsSinceEpoch(card.due), now.add(const Duration(days: 1)));

    card = FsrsScheduler.applyGood(card, now);
    expect(card.reps, 2);
    expect(DateTime.fromMillisecondsSinceEpoch(card.due), now.add(const Duration(days: 3)));

    card = FsrsScheduler.applyGood(card, now);
    expect(card.reps, 3);
    expect(DateTime.fromMillisecondsSinceEpoch(card.due), now.add(const Duration(days: 7)));
  });
}

