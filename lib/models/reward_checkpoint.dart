import 'map_location.dart';

class RewardCheckpoint {
  const RewardCheckpoint({
    required this.id,
    required this.locationType,
    required this.locationId,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.active = true,
  });

  // Stable across different reward spawns.
  final String id;

  // Parent place: a registered business or a landmark.
  // locationId is the original record ID, not a prefixed map UI ID.
  final MapLocationType locationType;
  final String locationId;

  final String label;
  final double latitude;
  final double longitude;
  final bool active;

  bool get hasValidCoordinates {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  // Structural eligibility only.
  // Real placement approval and parent-place status are checked separately.
  bool get canSpawn {
    return active &&
        id.trim().isNotEmpty &&
        locationId.trim().isNotEmpty &&
        hasValidCoordinates;
  }
}
