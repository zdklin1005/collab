import 'package:cloud_firestore/cloud_firestore.dart';

import 'map_exp_claim_store.dart';

class MapHistorySnapshot<T> {
  const MapHistorySnapshot({
    required this.data,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final T data;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get serverConfirmed => !isFromCache && !hasPendingWrites;
}

class MapCheckpointCooldown {
  const MapCheckpointCooldown({
    required this.checkpointId,
    required this.batchStart,
    required this.nextEligibleAt,
  });

  final String checkpointId;
  final DateTime batchStart;
  final DateTime nextEligibleAt;

  bool blocksBatch({
    required DateTime candidateBatchStart,
    required DateTime now,
  }) {
    // Remaining markers in the same daily batch stay collectable.
    return !batchStart.isAtSameMomentAs(candidateBatchStart) &&
        now.isBefore(nextEligibleAt);
  }
}

class MapExpHistoryRepository {
  MapExpHistoryRepository({required FirebaseFirestore firestore})
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

  Stream<MapHistorySnapshot<Set<String>>> watchClaimedRewardIds(String uid) {
    return _user(uid)
        .collection('rewardClaims')
        .where('type', isEqualTo: 'exp')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final ids = <String>{};

          for (final document in snapshot.docs) {
            final rewardId = document.data()['rewardId'];

            if (rewardId is! String ||
                rewardId.trim().isEmpty ||
                document.id != MapExpClaimStore.claimIdFor(rewardId)) {
              throw StateError('Invalid saved map EXP claim.');
            }

            ids.add(rewardId);
          }

          return MapHistorySnapshot(
            data: Set<String>.unmodifiable(ids),
            isFromCache: snapshot.metadata.isFromCache,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
          );
        });
  }

  Stream<MapHistorySnapshot<Map<String, MapCheckpointCooldown>>>
  watchCheckpointCooldowns(String uid) {
    return _user(uid)
        .collection('checkpointCooldowns')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final cooldowns = <String, MapCheckpointCooldown>{};

          for (final document in snapshot.docs) {
            final data = document.data();
            final checkpointId = data['checkpointId'];
            final batchStart = data['batchStart'];
            final nextEligibleAt = data['nextEligibleAt'];

            if (checkpointId is! String ||
                checkpointId.trim().isEmpty ||
                document.id != MapExpClaimStore.cooldownIdFor(checkpointId) ||
                batchStart is! Timestamp ||
                nextEligibleAt is! Timestamp) {
              throw StateError('Invalid saved checkpoint cooldown.');
            }

            cooldowns[checkpointId] = MapCheckpointCooldown(
              checkpointId: checkpointId,
              batchStart: batchStart.toDate().toUtc(),
              nextEligibleAt: nextEligibleAt.toDate().toUtc(),
            );
          }

          return MapHistorySnapshot(
            data: Map<String, MapCheckpointCooldown>.unmodifiable(cooldowns),
            isFromCache: snapshot.metadata.isFromCache,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
          );
        });
  }
}
