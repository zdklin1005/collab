import '../../models/reward_marker.dart';
import 'reward_collection_check.dart';

enum LiveRewardCollectionStatus {
  ready,
  simulationBlocked,
  sourceUnavailable,
  rewardChanged,
  localCheckFailed,
}

class LiveRewardCollectionCheck {
  const LiveRewardCollectionCheck(this.status, {this.localCheck});

  final LiveRewardCollectionStatus status;
  final RewardCollectionCheck? localCheck;

  // Local eligibility only—not permission to write to Firestore.
  bool get canAttemptClaim => status == LiveRewardCollectionStatus.ready;
}

LiveRewardCollectionCheck checkLiveRewardCollection({
  required RewardMarker selectedReward,
  required Iterable<RewardMarker> currentRewards,
  required bool sourceReady,
  required bool simulationActive,
  required DateTime now,
  required bool appIsForeground,
  required bool locationAllowed,
  required double radiusMeters,
  required double? userLatitude,
  required double? userLongitude,
  required double? accuracyMeters,
  required DateTime? recordedAt,
}) {
  if (simulationActive) {
    return const LiveRewardCollectionCheck(
      LiveRewardCollectionStatus.simulationBlocked,
    );
  }

  if (!sourceReady) {
    return const LiveRewardCollectionCheck(
      LiveRewardCollectionStatus.sourceUnavailable,
    );
  }

  final matches = currentRewards
      .where((reward) => reward.id == selectedReward.id)
      .toList();

  // Reject missing or ambiguous IDs as well as changed reward data.
  if (matches.length != 1 || !_sameReward(selectedReward, matches.single)) {
    return const LiveRewardCollectionCheck(
      LiveRewardCollectionStatus.rewardChanged,
    );
  }

  final localCheck = checkRewardCollection(
    reward: matches.single,
    now: now,
    appIsForeground: appIsForeground,
    locationAllowed: locationAllowed,
    radiusMeters: radiusMeters,
    userLatitude: userLatitude,
    userLongitude: userLongitude,
    accuracyMeters: accuracyMeters,
    recordedAt: recordedAt,
  );

  // The existing shared checker uses the old prototype status name.
  final passed = localCheck.status == RewardCollectionCheckStatus.readyForDemo;

  return LiveRewardCollectionCheck(
    passed
        ? LiveRewardCollectionStatus.ready
        : LiveRewardCollectionStatus.localCheckFailed,
    localCheck: localCheck,
  );
}

bool _sameReward(RewardMarker selected, RewardMarker current) {
  return selected.id == current.id &&
      selected.checkpointId == current.checkpointId &&
      selected.locationType == current.locationType &&
      selected.locationId == current.locationId &&
      selected.type == current.type &&
      selected.title == current.title &&
      selected.description == current.description &&
      selected.latitude == current.latitude &&
      selected.longitude == current.longitude &&
      selected.expAmount == current.expAmount &&
      selected.voucherId == current.voucherId &&
      selected.active == current.active &&
      selected.availableFrom.isAtSameMomentAs(current.availableFrom) &&
      selected.expiresAt.isAtSameMomentAs(current.expiresAt);
}
