import 'dart:math' as math;

/// Straight-line surface distance only, not walking-route distance or proof
/// that a reward can be collected. Permission, GPS quality, availability,
/// cooldown and backend validation must be checked separately.
class RewardProximity {
  static const double _earthRadiusMeters = 6371000;

  static double distanceMeters({
    required double userLatitude,
    required double userLongitude,
    required double rewardLatitude,
    required double rewardLongitude,
  }) {
    _validateCoordinates(userLatitude, userLongitude);
    _validateCoordinates(rewardLatitude, rewardLongitude);

    final lat1 = userLatitude * math.pi / 180;
    final lat2 = rewardLatitude * math.pi / 180;
    final deltaLat = lat2 - lat1;
    final deltaLng = (rewardLongitude - userLongitude) * math.pi / 180;
    final sinLat = math.sin(deltaLat / 2);
    final sinLng = math.sin(deltaLng / 2);
    final a =
        (sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng)
            .clamp(0.0, 1.0);

    return 2 * _earthRadiusMeters * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Includes the exact boundary. Compare full precision; round only for UI.
  /// No default radius: the caller must supply the agreed checkpoint policy.
  static bool isWithinRadius({
    required double distanceMeters,
    required double radiusMeters,
  }) {
    if (!distanceMeters.isFinite || distanceMeters < 0) {
      throw ArgumentError.value(
        distanceMeters,
        'distanceMeters',
        'Must be finite and non-negative.',
      );
    }
    if (!radiusMeters.isFinite || radiusMeters <= 0) {
      throw ArgumentError.value(
        radiusMeters,
        'radiusMeters',
        'Must be finite and positive.',
      );
    }
    return distanceMeters <= radiusMeters;
  }

  static void _validateCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError(
        'Coordinates must be finite and within valid ranges.',
      );
    }
  }
}
