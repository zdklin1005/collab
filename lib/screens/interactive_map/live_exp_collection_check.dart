import '../../models/reward_marker.dart';
import 'reward_collection_check.dart';

import '../../services/current_reward_validation.dart';

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

  final current = findMatchingCurrentReward(
    selected: selectedReward,
    currentRewards: currentRewards,
    now: now,
  );

  if (current == null) {
    return const LiveRewardCollectionCheck(
      LiveRewardCollectionStatus.rewardChanged,
    );
  }

  final localCheck = checkRewardCollection(
    reward: current,
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
