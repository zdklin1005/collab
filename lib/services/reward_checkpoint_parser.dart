import '../models/map_location.dart';
import '../models/reward_checkpoint.dart';

RewardCheckpoint? parseRewardCheckpoint(
  String documentId,
  Map<String, dynamic> data,
) {
  final locationType = switch (data['locationType']) {
    'business' => MapLocationType.business,
    'landmark' => MapLocationType.landmark,
    _ => null,
  };

  final locationId = data['locationId'];
  final label = data['label'];
  final latitude = data['latitude'];
  final longitude = data['longitude'];

  if (documentId.trim().isEmpty ||
      locationType == null ||
      locationId is! String ||
      locationId.trim().isEmpty ||
      label is! String ||
      label.trim().isEmpty ||
      latitude is! num ||
      longitude is! num ||
      data['active'] != true ||
      data['placementApproved'] != true) {
    return null;
  }

  final checkpoint = RewardCheckpoint(
    id: documentId,
    locationType: locationType,
    // Preserve the actual parent document ID.
    locationId: locationId,
    label: label.trim(),
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
    active: true,
  );

  return checkpoint.canSpawn ? checkpoint : null;
}
