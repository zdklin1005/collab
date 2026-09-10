import '../models/reward_marker.dart';
import '../models/map_location.dart';

import 'dart:convert';

enum DemoMapClaimStatus {
  recorded,
  alreadyClaimed,
  rewardUnavailable,
  checkpointOnCooldown,
}

class DemoMapClaim {
  const DemoMapClaim({
    required this.touristId,
    required this.reward,
    required this.collectedAt,
  });

  final String touristId;

  // Immutable snapshot of the simulated reward.
  // This does not mean EXP was credited or a voucher was issued.
  final RewardMarker reward;

  final DateTime collectedAt;
}

/// In-memory development data only.
///
/// No Firebase writes, EXP updates, voucher issuing or stock changes.
/// A new store instance starts empty.
///
/// The caller must rerun checkRewardCollection immediately before recording.
/// This store additionally checks availability and duplicate claims.
class DemoMapClaimStore {
  final Map<String, Map<String, DemoMapClaim>> _claimsByTourist = {};
  static const checkpointCooldown = Duration(hours: 24);

  bool hasClaimed({required String touristId, required String spawnId}) {
    _validateId(touristId, 'touristId');
    _validateId(spawnId, 'spawnId');

    return _claimsByTourist[touristId]?.containsKey(spawnId) ?? false;
  }

  List<DemoMapClaim> claimsFor(String touristId) {
    _validateId(touristId, 'touristId');

    return List<DemoMapClaim>.unmodifiable(
      _claimsByTourist[touristId]?.values ?? <DemoMapClaim>[],
    );
  }

  DateTime? nextEligibleAt({
    required String touristId,
    required String checkpointId,
  }) {
    _validateId(touristId, 'touristId');
    _validateId(checkpointId, 'checkpointId');

    DateTime? latestClaimTime;

    for (final claim in claimsFor(touristId)) {
      if (claim.reward.checkpointId != checkpointId) {
        continue;
      }

      final previous = latestClaimTime;

      if (previous == null || claim.collectedAt.isAfter(previous)) {
        latestClaimTime = claim.collectedAt;
      }
    }

    return latestClaimTime?.add(checkpointCooldown);
  }

  DemoMapClaimStatus recordDemoClaim({
    required String touristId,
    required RewardMarker reward,
    required DateTime now,
  }) {
    _validateId(touristId, 'touristId');

    if (!reward.canDisplayAt(now)) {
      return DemoMapClaimStatus.rewardUnavailable;
    }

    final touristClaims = _claimsByTourist.putIfAbsent(
      touristId,
      () => <String, DemoMapClaim>{},
    );

    if (touristClaims.containsKey(reward.id)) {
      return DemoMapClaimStatus.alreadyClaimed;
    }

    final eligibleAt = nextEligibleAt(
      touristId: touristId,
      checkpointId: reward.checkpointId,
    );

    if (eligibleAt != null && now.toUtc().isBefore(eligibleAt)) {
      return DemoMapClaimStatus.checkpointOnCooldown;
    }

    // Synchronous check and insertion: repeated calls to this store
    // cannot record the same tourist/spawn pair twice.
    touristClaims[reward.id] = DemoMapClaim(
      touristId: touristId,
      reward: reward,
      collectedAt: now.toUtc(),
    );

    return DemoMapClaimStatus.recorded;
  }

  /// Encodes all tourists' demo claims into a versioned snapshot.
  String exportSnapshot() {
    final claims = _claimsByTourist.values.expand(
      (touristClaims) => touristClaims.values,
    );

    return jsonEncode({
      'version': 1,
      'claims': claims.map((claim) {
        final reward = claim.reward;

        return {
          'touristId': claim.touristId,
          'collectedAt': claim.collectedAt.toUtc().toIso8601String(),
          'reward': {
            'id': reward.id,
            'checkpointId': reward.checkpointId,
            'locationType': reward.locationType.name,
            'locationId': reward.locationId,
            'type': reward.type.name,
            'title': reward.title,
            'description': reward.description,
            'latitude': reward.latitude,
            'longitude': reward.longitude,
            'expAmount': reward.expAmount,
            'voucherId': reward.voucherId,
            'availableFrom': reward.availableFrom.toUtc().toIso8601String(),
            'expiresAt': reward.expiresAt.toUtc().toIso8601String(),
            'active': reward.active,
          },
        };
      }).toList(),
    });
  }

  /// Restores a separate store without modifying an existing one.
  ///
  /// Invalid snapshots throw instead of silently resetting claim history.
  static DemoMapClaimStore fromSnapshot(String source) {
    try {
      final data = jsonDecode(source) as Map<String, dynamic>;

      if (data['version'] != 1) {
        throw const FormatException('Unsupported demo claim version.');
      }

      final records = data['claims'] as List<dynamic>;

      final claims = records.map((entry) {
        final record = entry as Map<String, dynamic>;
        final reward = record['reward'] as Map<String, dynamic>;

        return DemoMapClaim(
          touristId: record['touristId'] as String,
          collectedAt: DateTime.parse(record['collectedAt'] as String).toUtc(),
          reward: RewardMarker(
            id: reward['id'] as String,
            checkpointId: reward['checkpointId'] as String,
            locationType: MapLocationType.values.byName(
              reward['locationType'] as String,
            ),
            locationId: reward['locationId'] as String,
            type: RewardType.values.byName(reward['type'] as String),
            title: reward['title'] as String,
            description: reward['description'] as String,
            latitude: (reward['latitude'] as num).toDouble(),
            longitude: (reward['longitude'] as num).toDouble(),
            expAmount: reward['expAmount'] as int,
            voucherId: reward['voucherId'] as String?,
            availableFrom: DateTime.parse(
              reward['availableFrom'] as String,
            ).toUtc(),
            expiresAt: DateTime.parse(reward['expiresAt'] as String).toUtc(),
            active: reward['active'] as bool,
          ),
        );
      }).toList()..sort((a, b) => a.collectedAt.compareTo(b.collectedAt));

      final restored = DemoMapClaimStore();

      for (final claim in claims) {
        // Validate against the ORIGINAL collection time.
        // An expired spawn can still have a valid historical claim.
        final result = restored.recordDemoClaim(
          touristId: claim.touristId,
          reward: claim.reward,
          now: claim.collectedAt,
        );

        if (result != DemoMapClaimStatus.recorded) {
          throw const FormatException(
            'Invalid or duplicate demo claim history.',
          );
        }
      }

      return restored;
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('Invalid demo claim data types.');
    } on ArgumentError {
      throw const FormatException('Invalid demo claim values.');
    }
  }

  static void _validateId(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be empty.');
    }
  }
}
