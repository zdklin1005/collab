import 'package:cloud_firestore/cloud_firestore.dart';

class LocationHistoryService {
  LocationHistoryService._();
  static final instance = LocationHistoryService._();
  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Idempotent — safe to call every time proximity is confirmed;
  /// it just refreshes `visitedAt` rather than creating duplicates.
  Future<void> recordVisit(String uid, String businessId) async {
    await db.collection('users').doc(uid)
        .collection('visitedPlaces').doc(businessId)
        .set({
      'businessId': businessId,
      'visitedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasVisited(String uid, String businessId) async {
    final doc = await db.collection('users').doc(uid)
        .collection('visitedPlaces').doc(businessId).get();
    return doc.exists;
  }
}