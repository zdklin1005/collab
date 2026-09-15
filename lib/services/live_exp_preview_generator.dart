import 'dart:convert';
import 'dart:math' as math;

import '../models/map_location.dart';
import '../models/reward_marker.dart';
import 'daily_reward_generator.dart';
import 'place_checkpoint_adapter.dart';

// Stable selection across app restarts and input ordering.
int _pick(String seed) {
  var value = 0;
  for (final byte in utf8.encode(seed)) {
    value = (value * 131 + byte) % 2147483647;
  }
  value = (value * 48271) % 2147483647;
  return (value * 48271) % 2147483647;
}

double _fraction(String seed) => _pick(seed) / 2147483647;

/// Development previews only. No claims or account awards are written.
List<RewardMarker> generateLiveExpPreviews({
  required Iterable<MapLocation> places,
  required DateTime instant,
  int spawnPercent = 80,
}) {
  final checkpoints = derivePlaceCheckpoints(places);

  final businessIds = checkpoints
      .where((c) => c.locationType == MapLocationType.business)
      .map((c) => c.locationId)
      .toSet();

  final landmarkIds = checkpoints
      .where((c) => c.locationType == MapLocationType.landmark)
      .map((c) => c.locationId)
      .toSet();

  final selected =
      DailyRewardGenerator(
        spawnPercent: spawnPercent,
        voucherPercent: 0,
      ).generate(
        instant: instant,
        checkpoints: checkpoints,
        activeBusinessIds: businessIds,
        activeLandmarkIds: landmarkIds,
      );

  final rewards = <RewardMarker>[];

  for (final base in selected) {
    final seed = 'cluster-v1:${base.id}';
    final count = 1 + _pick('$seed:count') % 5;
    final rotation = _fraction('$seed:rotation') * 2 * math.pi;
    final sector = 2 * math.pi / count;

    for (var index = 0; index < count; index++) {
      final slotSeed = '$seed:$index';

      // Scatter within a 5–15 metre ring.
      final metres = math.sqrt(25 + _fraction('$slotSeed:distance') * 200);

      // Separate angular sectors reduce bunching within one group.
      final jitter = (_fraction('$slotSeed:angle') - 0.5) * sector * 0.3;
      final bearing = rotation + index * sector + jitter;

      final latitude = base.latitude * math.pi / 180;
      final longitude = base.longitude * math.pi / 180;
      final angularDistance = metres / 6371000;

      final sinDestination =
          math.sin(latitude) * math.cos(angularDistance) +
          math.cos(latitude) * math.sin(angularDistance) * math.cos(bearing);

      final destinationLatitude = math.asin(
        sinDestination.clamp(-1.0, 1.0).toDouble(),
      );

      final destinationLongitude =
          longitude +
          math.atan2(
            math.sin(bearing) * math.sin(angularDistance) * math.cos(latitude),
            math.cos(angularDistance) -
                math.sin(latitude) * math.sin(destinationLatitude),
          );

      rewards.add(
        RewardMarker(
          id: slotSeed,
          checkpointId: base.checkpointId,
          locationType: base.locationType,
          locationId: base.locationId,
          type: RewardType.exp,
          title: base.title,
          description: base.description,
          latitude: destinationLatitude * 180 / math.pi,
          longitude: (destinationLongitude * 180 / math.pi + 540) % 360 - 180,
          expAmount: base.expAmount,
          availableFrom: base.availableFrom,
          expiresAt: base.expiresAt,
        ),
      );
    }
  }

  return List<RewardMarker>.unmodifiable(rewards);
}
