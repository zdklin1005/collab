import 'package:collab/models/map_location.dart';

MapLocation? parseLandmark(String documentId, Map<String, dynamic> data) {
  final title = data['title'];
  final category = data['category'];
  final address = data['address'];
  final description = data['description'];
  final latitude = data['latitude'];
  final longitude = data['longitude'];

  if (documentId.trim().isEmpty ||
      data['active'] != true ||
      title is! String ||
      title.trim().isEmpty ||
      category is! String ||
      category.trim().isEmpty ||
      address is! String ||
      address.trim().isEmpty ||
      (description != null && description is! String) ||
      latitude is! num ||
      longitude is! num) {
    return null;
  }

  final location = MapLocation(
    id: 'landmark:$documentId',
    type: MapLocationType.landmark,
    title: title.trim(),
    category: category.trim(),
    address: address.trim(),
    description: description is String ? description.trim() : '',
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
    active: true,
    sourceDocumentId: documentId,
    rewardPlacementApproved: data['rewardPlacementApproved'] == true,
  );

  return location.canDisplay ? location : null;
}
