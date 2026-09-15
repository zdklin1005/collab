import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/map_location.dart';
import '../models/reward_marker.dart';
import 'current_reward_validation.dart';
import 'live_exp_preview_generator.dart';
import 'map_exp_claim_store.dart';

class MapExpClaimBlocked implements Exception {
  const MapExpClaimBlocked(this.message);

  final String message;
}

class LiveMapExpClaimService {
  LiveMapExpClaimService({
    FirebaseFirestore? firestore,
    String? Function()? currentUserId,
    DateTime Function()? clock,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final String? Function() _currentUserId;
  final DateTime Function() _clock;

  void _requireAccount(String uid) {
    if (_currentUserId() != uid) {
      throw const MapExpClaimBlocked(
        'Your account changed. Return to Discover and try again.',
      );
    }
  }

  Future<MapExpClaimResult> collect({
    required String uid,
    required RewardMarker reward,
    required bool simulationActive,
    required Future<void> Function() revalidateDeviceAndReward,
  }) async {
    _requireAccount(uid);

    if (simulationActive) {
      return const MapExpClaimResult(MapExpClaimStatus.simulationBlocked);
    }

    if (reward.type != RewardType.exp ||
        !reward.hasValidDefinition ||
        reward.locationId.contains('/') ||
        reward.locationId == '.' ||
        reward.locationId == '..') {
      return const MapExpClaimResult(MapExpClaimStatus.rewardUnavailable);
    }

    final collection = reward.locationType == MapLocationType.business
        ? 'businesses'
        : 'landmarks';

    final sourceRef = _firestore.collection(collection).doc(reward.locationId);

    final store = MapExpClaimStore(firestore: _firestore, clock: _clock);

    return await store.commitValidatedExpClaim(
      uid: uid,
      reward: reward,
      simulationActive: simulationActive,
      validateBeforeAward: (transaction) async {
        _requireAccount(uid);

        // Reading through the transaction makes a concurrent source
        // change cause a transaction retry.
        final sourceSnapshot = await transaction.get(sourceRef);
        final data = sourceSnapshot.data();

        if (data == null) {
          throw const MapExpClaimBlocked(
            'This reward location is no longer available.',
          );
        }

        final title =
            data[reward.locationType == MapLocationType.business
                ? 'name'
                : 'title'];
        final latitude = data['latitude'];
        final longitude = data['longitude'];

        if (data['active'] != true ||
            data['rewardPlacementApproved'] != true ||
            title is! String ||
            title.trim().isEmpty ||
            latitude is! num ||
            longitude is! num) {
          throw const MapExpClaimBlocked(
            'This location is no longer approved for reward collection.',
          );
        }

        final source = MapLocation(
          id: '${reward.locationType.name}:${sourceSnapshot.id}',
          sourceDocumentId: sourceSnapshot.id,
          type: reward.locationType,
          title: title.trim(),
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          active: true,
          rewardPlacementApproved: true,
        );

        // Regenerate the approved source's base EXP slots using the
        // same default generation settings as the live map.
        final current = findMatchingCurrentReward(
          selected: reward,
          currentRewards: generateLiveExpPreviews(
            places: [source],
            instant: _clock(),
          ),
          now: _clock(),
        );

        if (current == null) {
          throw const MapExpClaimBlocked(
            'This reward changed or expired. Close the preview and try again.',
          );
        }

        // Also checks the map's current EXP/voucher selection, native GPS,
        // foreground state, permissions, distance and history readiness.
        // This callback must not award anything or open dialogs.
        await revalidateDeviceAndReward();

        _requireAccount(uid);
      },
    );
  }
}
