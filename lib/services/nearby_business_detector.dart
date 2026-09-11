import '../models/localquest_models.dart';
import 'reward_proximity.dart';

class NearbyBusiness {
  const NearbyBusiness({required this.business, required this.distanceMeters});

  final Business business;
  final double distanceMeters;
}

/// Finds nearby businesses from the supplied records.
///
/// The caller must first verify foreground state, permission,
/// and location freshness/accuracy.
///
/// This does not verify registration with the backend,
/// provide walking routes, or authorize voucher claims.
List<NearbyBusiness> findNearbyBusinesses({
  required Iterable<Business> businesses,
  required double userLatitude,
  required double userLongitude,
  required double radiusMeters,
}) {
  // Validate configuration even when the business list is empty.
  RewardProximity.isWithinRadius(distanceMeters: 0, radiusMeters: radiusMeters);

  // Reuse the existing coordinate validation.
  RewardProximity.distanceMeters(
    userLatitude: userLatitude,
    userLongitude: userLongitude,
    rewardLatitude: userLatitude,
    rewardLongitude: userLongitude,
  );

  final nearby = <NearbyBusiness>[];
  final includedIds = <String>{};

  for (final business in businesses) {
    final latitude = business.latitude;
    final longitude = business.longitude;

    if (!business.active ||
        business.id.trim().isEmpty ||
        business.ownerId.trim().isEmpty ||
        business.name.trim().isEmpty ||
        latitude == null ||
        longitude == null) {
      continue;
    }

    double distance;

    try {
      distance = RewardProximity.distanceMeters(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        rewardLatitude: latitude,
        rewardLongitude: longitude,
      );
    } on ArgumentError {
      // One malformed business must not break the entire result.
      continue;
    }

    if (!RewardProximity.isWithinRadius(
      distanceMeters: distance,
      radiusMeters: radiusMeters,
    )) {
      continue;
    }

    // Include each business once if the input contains duplicates.
    if (!includedIds.add(business.id)) continue;

    nearby.add(NearbyBusiness(business: business, distanceMeters: distance));
  }

  nearby.sort((a, b) {
    final distanceOrder = a.distanceMeters.compareTo(b.distanceMeters);

    return distanceOrder != 0
        ? distanceOrder
        : a.business.id.compareTo(b.business.id);
  });

  return List<NearbyBusiness>.unmodifiable(nearby);
}
