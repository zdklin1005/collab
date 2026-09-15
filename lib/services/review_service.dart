import 'package:cloud_firestore/cloud_firestore.dart';

import 'location_history_service.dart';
import 'reward_service.dart';

class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.businessId,
    this.businessName = '',
    required this.rating,
    required this.text,
    required this.photoUrls,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String businessId;
  final String businessName;
  final double rating;
  final String text;
  final List<String> photoUrls;
  final DateTime createdAt;

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Review(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      businessId: data['businessId'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      text: data['text'] as String? ?? '',
      photoUrls: List<String>.from(data['photoUrls'] as List? ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessId': businessId,
      'businessName': businessName,
      'rating': rating,
      'text': text,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ReviewSubmissionResult {
  const ReviewSubmissionResult({
    required this.success,
    this.failureReason,
    this.review,
    this.expAwarded = 0,
    this.levelUpResult,
  });

  final bool success;
  final String? failureReason;
  final Review? review;
  final int expAwarded;
  final ExpAwardResult? levelUpResult;
}


/// Handles business reviews/ratings, including the "did they actually
/// visit" verification.
///
/// STUB WARNING: `_hasVisitedStub()` currently always returns true. The
/// real check should query `users/{uid}/visitedPlaces` (the subcollection
/// already referenced in `UserRepository`), but as of now that
/// subcollection has no real data being written to it by anyone yet —
/// confirm with whoever owns Location History before wiring this up for
/// real, then swap just that one function's body.
///
/// Photo attachments are accepted as a list of URLs (matching the shape
/// [Review.photoUrls] expects) but there's no upload step here — Storage
/// isn't usable yet (Blaze billing not enabled). Once it is, upload the
/// photo elsewhere (e.g. reusing whatever pattern `MerchantRepository`
/// uses for campaign posters) and pass the resulting URL(s) in.
class ReviewService {
  ReviewService._();
  static final instance = ReviewService._();

  FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore customDb) => _db = customDb;

  /// EXP awarded for leaving a review. This is an assumption, not
  /// something from the original spec — remove or adjust freely if the
  /// team doesn't want reviews to grant EXP.
  static const int _reviewExpReward = 15;

  CollectionReference<Map<String, dynamic>> _reviewsRef(String businessId) =>
      db.collection('businesses').doc(businessId).collection('reviews');

  /// STUB: always returns true. Replace with a real query once
  /// `visitedPlaces` has data, e.g.:
  /// ```dart
  /// final visits = await db.collection('users').doc(uid)
  ///     .collection('visitedPlaces')
  ///     .where('businessId', isEqualTo: businessId)
  ///     .limit(1).get();
  /// return visits.docs.isNotEmpty;
  /// ```
  /// Checks whether the user has visited this business by querying visitedPlaces.
  Future<bool> hasVisited(String uid, String businessId) async {
    return LocationHistoryService.instance.hasVisited(uid, businessId);
  }

  /// Submits a review for [businessId] by [uid]. Verifies the tourist
  /// has visited first, writes the
  /// review, increments the tourist's `reviewCount` on their user doc
  /// (field already exists on `AppUser`), and updates a running rating
  /// total on the business doc.
  ///
  /// NOTE: `Business` doesn't currently have `reviewCount`/`ratingTotal`
  /// fields in its model — like the streak fields, these are written as
  /// plain extra fields directly on the business document rather than
  /// editing `localquest_models.dart`, to avoid touching a teammate's
  /// in-progress file. Average rating = ratingTotal / reviewCount.
  Future<ReviewSubmissionResult> submitReview({
    required String uid,
    required String businessId,
    required String businessName,
    required double rating,
    String text = '',
    List<String> photoUrls = const [],
    bool bypassVisitedCheck = false,
  }) async {
    if (rating < 1 || rating > 5) {
      return const ReviewSubmissionResult(
        success: false,
        failureReason: 'Rating must be between 1 and 5.',
      );
    }

    final visited = bypassVisitedCheck || await hasVisited(uid, businessId);
    if (!visited) {
      return const ReviewSubmissionResult(
        success: false,
        failureReason:
            'You need to have visited this business before reviewing it.',
      );
    }

    final review = Review(
      id: '',
      userId: uid,
      businessId: businessId,
      businessName: businessName,
      rating: rating,
      text: text,
      photoUrls: photoUrls,
      createdAt: DateTime.now(),
    );

    final reviewDocRef = await _reviewsRef(businessId).add(review.toMap());

    final batch = db.batch();
    batch.update(db.collection('users').doc(uid), {
      'reviewCount': FieldValue.increment(1),
    });
    batch.set(db.collection('businesses').doc(businessId), {
      'reviewCount': FieldValue.increment(1),
      'ratingTotal': FieldValue.increment(rating),
    }, SetOptions(merge: true));
    await batch.commit();

    final awardResult = await RewardService.instance.awardExp(
      uid,
      _reviewExpReward,
      reason: 'review_submitted',
    );

    return ReviewSubmissionResult(
      success: true,
      review: Review.fromDoc(await reviewDocRef.get()),
      expAwarded: _reviewExpReward,
      levelUpResult: awardResult.leveledUp ? awardResult : null,
    );
  }

  /// Fetches all reviews for [businessId], most recent first.
  Future<List<Review>> getReviewsForBusiness(String businessId) async {
    final snapshot = await _reviewsRef(
      businessId,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(Review.fromDoc).toList();
  }

  /// Average rating for a business, computed from the running total
  /// stored on the business doc's `ratingTotal`/`reviewCount` fields.
  Future<double> getAverageRating(String businessId) async {
    final doc = await db.collection('businesses').doc(businessId).get();
    final data = doc.data() ?? {};
    final count = (data['reviewCount'] as num?)?.toInt() ?? 0;
    final total = (data['ratingTotal'] as num?)?.toDouble() ?? 0;
    if (count == 0) return 0;
    return total / count;
  }

  /// Live stream of every review [uid] has posted, most recent first,
  /// across all businesses. Reviews live in per-business subcollections
  /// (`businesses/{id}/reviews`), so this uses a collection-group query
  /// rather than a single collection reference. Firestore's security
  /// rules already permit this — they match by document path
  /// (`businesses/*/reviews/*`), not by how the query was issued, so no
  /// rules change is needed. Firestore WILL require a composite index
  /// for this (userId + createdAt) — see the index note below.
  Stream<List<Review>> watchReviewsForUser(String uid) {
    return db
        .collectionGroup('reviews')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Review.fromDoc).toList());
  }
}
