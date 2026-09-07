enum RewardType {
  exp,
  voucher,
}

class RewardMarker {
  const RewardMarker({
    required this.id,
    required this.checkpointId,
    required this.businessId,
    required this.type,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.availableFrom,
    required this.expiresAt,
    this.description = '',
    this.expAmount = 0,
    this.voucherId,
    this.active = true,
  });

  // Identifies this particular generated reward.
  final String id;

  // Stable checkpoint identifier, unchanged when a new reward spawns.
  final String checkpointId;

  // Registered local business associated with this checkpoint.
  final String businessId;

  final RewardType type;
  final String title;
  final String description;

  // Snapshot of the approved checkpoint coordinates.
  final double latitude;
  final double longitude;

  // Positive for EXP rewards; zero for voucher rewards.
  final int expAmount;

  // Reference to an existing merchant voucher offer.
  // Null for EXP rewards.
  final String? voucherId;

  // Shared spawn availability, not a tourist's personal cooldown.
  final DateTime availableFrom;
  final DateTime expiresAt;
  final bool active;

  bool get hasValidCoordinates {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  bool get hasValidRewardData {
    return switch (type) {
      RewardType.exp => expAmount > 0 && voucherId == null,
      RewardType.voucher =>
        expAmount == 0 &&
            voucherId != null &&
            voucherId!.trim().isNotEmpty,
    };
  }

  bool get hasValidDefinition {
    return id.trim().isNotEmpty &&
        checkpointId.trim().isNotEmpty &&
        businessId.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        hasValidCoordinates &&
        hasValidRewardData &&
        expiresAt.isAfter(availableFrom);
  }

  // Shared display eligibility only.
  // Personal collection history and voucher stock are checked separately.
  bool canDisplayAt(DateTime now) {
    return hasValidDefinition &&
        active &&
        !now.isBefore(availableFrom) &&
        now.isBefore(expiresAt);
  }
}