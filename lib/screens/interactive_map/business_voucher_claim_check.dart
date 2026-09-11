import '../../models/localquest_models.dart';
import '../../services/business_voucher_availability.dart';
import '../../services/daily_reward_generator.dart';
import '../../services/reward_proximity.dart';
import 'location_quality.dart';

enum BusinessVoucherClaimStatus {
  readyForDemo,
  accountRequired,
  appInactive,
  voucherUnavailable,
  locationAccessRequired,
  locationUnavailable,
  locationUnreliable,
  invalidCoordinates,
  outOfRange,
  alreadyClaimed,
  historyUnavailable,
  demoRecorded,
  claimInProgress,
  saveFailed,
}

/// Local prechecks only—not backend authorization.
///
/// Supply current business/offer records and the latest location/time.
/// Uses the caller's tourist-specific claim-history result.
/// Does not reserve stock or issue a voucher.
BusinessVoucherClaimStatus checkBusinessVoucherClaim({
  required String touristId,
  required Business business,
  required String selectedVoucherId,
  required Iterable<MapVoucherOffer> currentOffers,
  required DateTime now,
  required bool appIsForeground,
  required bool locationAllowed,
  required double radiusMeters,
  required double? userLatitude,
  required double? userLongitude,
  required double? accuracyMeters,
  required DateTime? recordedAt,
  required bool hasAlreadyClaimed,
}) {
  // Reject invalid configuration even if other checks would fail.
  RewardProximity.isWithinRadius(distanceMeters: 0, radiusMeters: radiusMeters);

  if (touristId.trim().isEmpty) {
    return BusinessVoucherClaimStatus.accountRequired;
  }

  if (!appIsForeground) {
    return BusinessVoucherClaimStatus.appInactive;
  }

  // A business offer is claimable only once per tourist.
  // Changing its dates or stock does not reset that history.
  if (hasAlreadyClaimed) {
    return BusinessVoucherClaimStatus.alreadyClaimed;
  }

  final matching = currentOffers
      .where((offer) => offer.id == selectedVoucherId)
      .toList();

  // Missing or ambiguous offer identity must not permit a claim.
  if (selectedVoucherId.trim().isEmpty ||
      matching.length != 1 ||
      availableBusinessVouchers(
        business: business,
        offers: matching,
        now: now,
      ).isEmpty) {
    return BusinessVoucherClaimStatus.voucherUnavailable;
  }

  if (!locationAllowed) {
    return BusinessVoucherClaimStatus.locationAccessRequired;
  }

  if (userLatitude == null || userLongitude == null || recordedAt == null) {
    return BusinessVoucherClaimStatus.locationUnavailable;
  }

  if (assessLocationQuality(
        accuracy: accuracyMeters,
        recordedAt: recordedAt,
        now: now,
      ) !=
      LocationQuality.recent) {
    return BusinessVoucherClaimStatus.locationUnreliable;
  }

  final businessLatitude = business.latitude;
  final businessLongitude = business.longitude;

  if (businessLatitude == null || businessLongitude == null) {
    return BusinessVoucherClaimStatus.invalidCoordinates;
  }

  try {
    final distance = RewardProximity.distanceMeters(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      rewardLatitude: businessLatitude,
      rewardLongitude: businessLongitude,
    );

    return RewardProximity.isWithinRadius(
          distanceMeters: distance,
          radiusMeters: radiusMeters,
        )
        ? BusinessVoucherClaimStatus.readyForDemo
        : BusinessVoucherClaimStatus.outOfRange;
  } on ArgumentError {
    return BusinessVoucherClaimStatus.invalidCoordinates;
  }
}
