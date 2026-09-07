class RewardCheckpoint {
  const RewardCheckpoint({
    required this.id,
    required this.businessId,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.active = true,
  });

  // Stable across different reward spawns.
  final String id;

  final String businessId;
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
  // Real placement approval and business status are checked separately.
  bool get canSpawn {
    return active &&
        id.trim().isNotEmpty &&
        businessId.trim().isNotEmpty &&
        hasValidCoordinates;
  }
}