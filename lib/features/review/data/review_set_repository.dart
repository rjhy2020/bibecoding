import '../models/review_set.dart';

abstract class ReviewSetRepository {
  Future<String> createSet({
    required String title,
    required List<String> itemIds,
    DateTime? now,
  });

  Future<List<ReviewSet>> fetchDueSets({DateTime? now});
  Future<List<ReviewSet>> fetchAllSets();
  Future<void> deleteSet(String setId);
  Future<void> updateSetAfterReview(String setId, {required int rating, DateTime? now});

  Future<ReviewSet?> getById(String setId);
}

