import '../models/map_location.dart';
import '../models/reward_checkpoint.dart';

List<RewardCheckpoint> derivePlaceCheckpoints(Iterable<MapLocation> places) {
  final checkpoints = <String, RewardCheckpoint>{};

  for (final place in places) {
    final sourceId = place.sourceDocumentId;

    if (!place.canDisplay ||
        !place.rewardPlacementApproved ||
        place.title.trim().isEmpty ||
        sourceId == null ||
        sourceId.trim().isEmpty ||
        sourceId.contains('/') ||
        sourceId == '.' ||
        sourceId == '..') {
      continue;
    }

    // The type prefix prevents a business and landmark with the same
    // document ID from sharing checkpoint/claim identities.
    final checkpointId = '${place.type.name}:$sourceId';

    if (checkpoints.containsKey(checkpointId)) {
      throw ArgumentError('Duplicate place checkpoint: $checkpointId');
    }

    checkpoints[checkpointId] = RewardCheckpoint(
      id: checkpointId,
      locationType: place.type,
      locationId: sourceId,
      label: '${place.title.trim()} checkpoint',
      latitude: place.latitude,
      longitude: place.longitude,
      active: true,
    );
  }

  final result = checkpoints.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  return List<RewardCheckpoint>.unmodifiable(result);
}
