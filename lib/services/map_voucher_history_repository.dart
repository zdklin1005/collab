import 'package:cloud_firestore/cloud_firestore.dart';

import 'map_exp_history_repository.dart';

class MapVoucherHistoryRepository {
  MapVoucherHistoryRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) {
    if (uid.trim().isEmpty ||
        uid != uid.trim() ||
        uid.contains('/') ||
        uid == '.' ||
        uid == '..') {
      throw ArgumentError.value(uid, 'uid', 'Invalid user ID');
    }

    return _firestore.collection('users').doc(uid);
  }

  Stream<MapHistorySnapshot<Set<String>>> watchClaimedVoucherIds(String uid) {
    return _user(uid)
        .collection('claimedVouchers')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final ids = <String>{};

          for (final document in snapshot.docs) {
            final voucherId = document.data()['voucherId'];

            if (voucherId is! String ||
                voucherId.trim().isEmpty ||
                document.id != voucherId) {
              throw StateError('Invalid saved voucher claim.');
            }

            ids.add(voucherId);
          }

          return MapHistorySnapshot(
            data: Set<String>.unmodifiable(ids),
            isFromCache: snapshot.metadata.isFromCache,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
          );
        });
  }
}
