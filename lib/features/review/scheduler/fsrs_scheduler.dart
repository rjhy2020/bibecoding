import '../models/review_card.dart';

class FsrsScheduler {
  // 간단 Good(2) 전용 간격 테이블(일)
  static const List<int> goodIntervalsDays = [1, 3, 7, 14, 30, 60, 120, 240];
  static const List<int> hardIntervalsDays = [1, 2, 4, 7, 15, 30, 60, 120];
  static const List<int> easyIntervalsDays = [2, 4, 8, 16, 32, 64, 128, 256];

  static int goodIntervalDaysForReps(int newReps) {
    final idx = (newReps - 1).clamp(0, goodIntervalsDays.length - 1);
    return goodIntervalsDays[idx];
  }

  static int hardIntervalDaysForReps(int newReps) {
    final idx = (newReps - 1).clamp(0, hardIntervalsDays.length - 1);
    return hardIntervalsDays[idx];
  }

  static int easyIntervalDaysForReps(int newReps) {
    final idx = (newReps - 1).clamp(0, easyIntervalsDays.length - 1);
    return easyIntervalsDays[idx];
  }

  static int intervalDaysForRating(int newReps, int rating) {
    switch (rating) {
      case 1:
        return hardIntervalDaysForReps(newReps);
      case 3:
        return easyIntervalDaysForReps(newReps);
      case 2:
      default:
        return goodIntervalDaysForReps(newReps);
    }
  }

  // 로컬 기준 자정(epoch millis)
  static int startOfDayMillis(DateTime t) => DateTime(t.year, t.month, t.day).millisecondsSinceEpoch;

  // 로컬 기준 자정 + days일(epoch millis)
  static int dueAtStartOfDayPlusDays(DateTime now, int days) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: days)).millisecondsSinceEpoch;

  static ReviewCard applyGood(ReviewCard card, DateTime now) {
    final newReps = card.reps + 1;
    final days = goodIntervalDaysForReps(newReps);
    final nextDue = dueAtStartOfDayPlusDays(now, days);
    return card.copyWith(
      reps: newReps,
      lastRating: 2,
      updatedAt: now.millisecondsSinceEpoch,
      due: nextDue,
      // 간단 초기값 유지: stability/difficulty는 향후 정식 FSRS로 조정
      stability: card.stability,
      difficulty: card.difficulty,
    );
  }

  static ReviewCard applyHard(ReviewCard card, DateTime now) {
    final newReps = card.reps + 1;
    final days = hardIntervalDaysForReps(newReps);
    final nextDue = dueAtStartOfDayPlusDays(now, days);
    return card.copyWith(
      reps: newReps,
      lastRating: 1,
      updatedAt: now.millisecondsSinceEpoch,
      due: nextDue,
      stability: card.stability,
      difficulty: card.difficulty,
    );
  }

  static ReviewCard applyEasy(ReviewCard card, DateTime now) {
    final newReps = card.reps + 1;
    final days = easyIntervalDaysForReps(newReps);
    final nextDue = dueAtStartOfDayPlusDays(now, days);
    return card.copyWith(
      reps: newReps,
      lastRating: 3,
      updatedAt: now.millisecondsSinceEpoch,
      due: nextDue,
      stability: card.stability,
      difficulty: card.difficulty,
    );
  }
}
