import '../models/review_card.dart';

abstract class ReviewRepository {
  Future<void> upsertAll(List<ReviewCard> cards);
  Future<List<ReviewCard>> fetchDue({DateTime? now});
  Future<List<ReviewCard>> fetchAll();
  Future<void> delete(String id);
  Future<void> updateAfterReview(String id, {required int rating, DateTime? now});
}

