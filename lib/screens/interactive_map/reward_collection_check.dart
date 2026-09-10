import '../../models/reward_marker.dart';
import '../../services/reward_proximity.dart';
import 'location_quality.dart';

enum RewardCollectionCheckStatus {
  readyForDemo,
  appInactive,
  rewardUnavailable,
  locationAccessRequired,
  locationUnavailable,
  locationUnreliable,
  invalidCoordinates,
  outOfRange,
}

class RewardCollectionCheck {
  const RewardCollectionCheck({
    required this.status,
    this.distanceMeters,
    this.locationQuality,
  });

  final RewardCollectionCheckStatus status;
  final double? distanceMeters;
  final LocationQuality? locationQuality;

  // Only local prechecks passed. This is NOT backend authorization.
  bool get canProceedToDemo =>
      status == RewardCollectionCheckStatus.readyForDemo;
}

/// Call again when collection is requested, using the latest position/time.
///
/// This does not check stock, individual claims, cooldowns or backend rules.
/// It does not award anything or modify the supplied reward.
RewardCollectionCheck checkRewardCollection({
  required RewardMarker reward,
  required DateTime now,
  required bool appIsForeground,
  required bool locationAllowed,
  required double radiusMeters,
  required double? userLatitude,
  required double? userLongitude,
  required double? accuracyMeters,
  required DateTime? recordedAt,
  double maximumAccuracyMeters = 25,
  Duration maximumLocationAge = const Duration(seconds: 30),
}) {
  // Configuration errors must not silently permit collection.
  if (!radiusMeters.isFinite || radiusMeters <= 0) {
    throw ArgumentError.value(radiusMeters, 'radiusMeters');
  }

  if (!maximumAccuracyMeters.isFinite || maximumAccuracyMeters <= 0) {
    throw ArgumentError.value(maximumAccuracyMeters, 'maximumAccuracyMeters');
  }

  if (maximumLocationAge <= Duration.zero) {
    throw ArgumentError.value(maximumLocationAge, 'maximumLocationAge');
  }

  if (!appIsForeground) {
    return const RewardCollectionCheck(
      status: RewardCollectionCheckStatus.appInactive,
    );
  }

  if (!reward.canDisplayAt(now)) {
    return const RewardCollectionCheck(
      status: RewardCollectionCheckStatus.rewardUnavailable,
    );
  }

  if (!locationAllowed) {
    return const RewardCollectionCheck(
      status: RewardCollectionCheckStatus.locationAccessRequired,
    );
  }

  if (userLatitude == null || userLongitude == null || recordedAt == null) {
    return const RewardCollectionCheck(
      status: RewardCollectionCheckStatus.locationUnavailable,
    );
  }

  final quality = assessLocationQuality(
    accuracy: accuracyMeters,
    recordedAt: recordedAt,
    now: now,
    warningAccuracyMetres: maximumAccuracyMeters,
    maximumAge: maximumLocationAge,
  );

  if (quality != LocationQuality.recent) {
    return RewardCollectionCheck(
      status: RewardCollectionCheckStatus.locationUnreliable,
      locationQuality: quality,
    );
  }

  try {
    final distance = RewardProximity.distanceMeters(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      rewardLatitude: reward.latitude,
      rewardLongitude: reward.longitude,
    );

    final withinRange = RewardProximity.isWithinRadius(
      distanceMeters: distance,
      radiusMeters: radiusMeters,
    );

    return RewardCollectionCheck(
      status: withinRange
          ? RewardCollectionCheckStatus.readyForDemo
          : RewardCollectionCheckStatus.outOfRange,
      distanceMeters: distance,
      locationQuality: quality,
    );
  } on ArgumentError {
    return RewardCollectionCheck(
      status: RewardCollectionCheckStatus.invalidCoordinates,
      locationQuality: quality,
    );
  }
}
