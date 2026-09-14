import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../models/reward_marker.dart';
import 'daily_reward_generator.dart';
import 'exp_award_service.dart';

enum MapExpClaimStatus {
  recorded,
  alreadyClaimed,
  rewardUnavailable,
  checkpointOnCooldown,
  simulationBlocked,
}

class MapExpClaimResult {
  const MapExpClaimResult(this.status, {this.receipt});

  final MapExpClaimStatus status;
  final ExpAwardReceipt? receipt;
}

/// Transaction persistence for a previously validated map collection.
///
/// Not a complete collection authorization service.
/// Keep disconnected from the live Collect button until source validation,
/// real-location checks, and Firestore rules are integrated.
class MapExpClaimStore {
  MapExpClaimStore({
    required FirebaseFirestore firestore,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _awards = ExpAwardService(firestore: firestore),
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final ExpAwardService _awards;
  final DateTime Function() _clock;

  static const cooldown = Duration(hours: 24);

  static String claimIdFor(String rewardId) {
    return ExpAwardService.awardIdFor(source: 'map_exp', sourceId: rewardId);
  }

  static String cooldownIdFor(String checkpointId) {
    return sha256.convert(utf8.encode(checkpointId)).toString();
  }

  Future<MapExpClaimResult> commitValidatedExpClaim({
    required String uid,
    required RewardMarker reward,
    required bool simulationActive,
  }) async {
    if (simulationActive) {
      return const MapExpClaimResult(MapExpClaimStatus.simulationBlocked);
    }

    if (uid.trim().isEmpty ||
        uid != uid.trim() ||
        uid.contains('/') ||
        uid == '.' ||
        uid == '..') {
      throw ArgumentError.value(uid, 'uid', 'Invalid user ID');
    }

    if (reward.type != RewardType.exp || !reward.hasValidDefinition) {
      return const MapExpClaimResult(MapExpClaimStatus.rewardUnavailable);
    }

    final claimId = claimIdFor(reward.id);
    final userRef = _firestore.collection('users').doc(uid);
    final claimRef = userRef.collection('rewardClaims').doc(claimId);
    final cooldownRef = userRef
        .collection('checkpointCooldowns')
        .doc(cooldownIdFor(reward.checkpointId));

    return _firestore.runTransaction<MapExpClaimResult>((transaction) async {
      final claimSnapshot = await transaction.get(claimRef);
      final cooldownSnapshot = await transaction.get(cooldownRef);

      if (claimSnapshot.exists) {
        return const MapExpClaimResult(MapExpClaimStatus.alreadyClaimed);
      }

      final now = _clock().toUtc();
      final batchStart = DailyRewardGenerator.dayStartUtc(now);

      if (!reward.canDisplayAt(now) ||
          reward.availableFrom.toUtc() != batchStart) {
        return const MapExpClaimResult(MapExpClaimStatus.rewardUnavailable);
      }

      final previous = cooldownSnapshot.data();
      if (previous != null) {
        final savedBatch = previous['batchStart'];
        final nextEligible = previous['nextEligibleAt'];

        if (previous['checkpointId'] != reward.checkpointId ||
            savedBatch is! Timestamp ||
            nextEligible is! Timestamp) {
          throw StateError('Invalid checkpoint cooldown record.');
        }

        final sameBatch = savedBatch.toDate().toUtc() == batchStart;

        // Other markers in the current daily batch remain collectable.
        // A new day's batch must wait for the existing cooldown.
        if (!sameBatch && now.isBefore(nextEligible.toDate())) {
          return const MapExpClaimResult(
            MapExpClaimStatus.checkpointOnCooldown,
          );
        }
      }

      // This reads the account and award log, then queues their writes.
      // No transaction reads may follow this call.
      final receipt = await _awards.awardInTransaction(
        transaction,
        uid: uid,
        source: 'map_exp',
        sourceId: reward.id,
        amount: reward.expAmount,
      );

      if (receipt.alreadyAwarded) {
        // Do not silently repair an award whose map claim is missing.
        throw StateError('An EXP award exists without its matching map claim.');
      }

      transaction.set(claimRef, {
        'rewardId': reward.id,
        'checkpointId': reward.checkpointId,
        'locationType': reward.locationType.name,
        'locationId': reward.locationId,
        'type': 'exp',
        'expAwarded': reward.expAmount,
        'awardId': receipt.awardId,
        'batchStart': Timestamp.fromDate(batchStart),
        'collectedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(cooldownRef, {
        'checkpointId': reward.checkpointId,
        'batchStart': Timestamp.fromDate(batchStart),
        'lastSpawnId': reward.id,
        'lastCollectedAt': FieldValue.serverTimestamp(),
        'nextEligibleAt': Timestamp.fromDate(now.add(cooldown)),
      });

      return MapExpClaimResult(MapExpClaimStatus.recorded, receipt: receipt);
    });
  }
}
