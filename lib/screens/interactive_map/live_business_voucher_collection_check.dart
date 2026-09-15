import '../../models/localquest_models.dart';
import '../../services/live_business_voucher_availability.dart';
import '../../services/reward_proximity.dart';
import 'location_quality.dart';

enum LiveBusinessVoucherCollectionStatus {
  ready,
  accountRequired,
  appInactive,
  voucherUnavailable,
  locationAccessRequired,
  locationUnavailable,
  locationUnreliable,
  invalidCoordinates,
  outOfRange,
}

class LiveBusinessVoucherCollectionCheck {
  const LiveBusinessVoucherCollectionCheck({
    required this.status,
    this.distanceMeters,
    this.locationQuality,
  });

  final LiveBusinessVoucherCollectionStatus status;
  final double? distanceMeters;
  final LocationQuality? locationQuality;

  bool get canClaim => status == LiveBusinessVoucherCollectionStatus.ready;
}

LiveBusinessVoucherCollectionCheck checkLiveBusinessVoucherCollection({
  required String touristId,
  required Business business,
  required String voucherId,
  required Iterable<Campaign> currentCampaigns,
  required DateTime now,
  required bool appIsForeground,
  required bool locationAllowed,
  required double radiusMeters,
  required double? userLatitude,
  required double? userLongitude,
  required double? accuracyMeters,
  required DateTime? recordedAt,
}) {
  RewardProximity.isWithinRadius(distanceMeters: 0, radiusMeters: radiusMeters);

  if (touristId.trim().isEmpty) {
    return const LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.accountRequired,
    );
  }

  if (!appIsForeground) {
    return const LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.appInactive,
    );
  }

  final matching = currentCampaigns
      .where((campaign) => campaign.id == voucherId)
      .toList();

  if (voucherId.trim().isEmpty ||
      matching.length != 1 ||
      availableDiscoveryVouchers(
        business: business,
        campaigns: matching,
        now: now,
      ).isEmpty) {
    return const LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.voucherUnavailable,
    );
  }

  if (!locationAllowed) {
    return const LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.locationAccessRequired,
    );
  }

  if (userLatitude == null || userLongitude == null || recordedAt == null) {
    return const LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.locationUnavailable,
    );
  }

  final quality = assessLocationQuality(
    accuracy: accuracyMeters,
    recordedAt: recordedAt,
    now: now,
  );

  if (quality != LocationQuality.recent) {
    return LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.locationUnreliable,
      locationQuality: quality,
    );
  }

  final businessLatitude = business.latitude;
  final businessLongitude = business.longitude;

  if (businessLatitude == null || businessLongitude == null) {
    return const LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.invalidCoordinates,
    );
  }

  try {
    final distance = RewardProximity.distanceMeters(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      rewardLatitude: businessLatitude,
      rewardLongitude: businessLongitude,
    );

    final withinRange = RewardProximity.isWithinRadius(
      distanceMeters: distance,
      radiusMeters: radiusMeters,
    );

    return LiveBusinessVoucherCollectionCheck(
      status: withinRange
          ? LiveBusinessVoucherCollectionStatus.ready
          : LiveBusinessVoucherCollectionStatus.outOfRange,
      distanceMeters: distance,
      locationQuality: quality,
    );
  } on ArgumentError {
    return LiveBusinessVoucherCollectionCheck(
      status: LiveBusinessVoucherCollectionStatus.invalidCoordinates,
      locationQuality: quality,
    );
  }
}
