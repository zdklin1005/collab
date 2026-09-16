import '../models/reward_marker.dart';

RewardMarker? findMatchingCurrentReward({
  required RewardMarker selected,
  required Iterable<RewardMarker> currentRewards,
  required DateTime now,
}) {
  final matches = currentRewards
      .where((reward) => reward.id == selected.id)
      .toList();

  if (matches.length != 1) return null;

  final current = matches.single;

  if (!current.canDisplayAt(now) || !_sameRewardSnapshot(selected, current)) {
    return null;
  }

  return current;
}

bool _sameRewardSnapshot(RewardMarker selected, RewardMarker current) {
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
