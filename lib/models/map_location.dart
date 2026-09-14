import 'localquest_models.dart';

enum MapLocationType { business, landmark }

class MapLocation {
  const MapLocation({
    required this.id,
    required this.type,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.description = '',
    this.address = '',
    this.category = '',
    this.businessId,
    this.operatingHours = '',
    this.phone = '',
    this.website = '',
    this.dietaryStatus = '',
    this.photoUrl,
    this.active = true,
  });

  // Map-specific identifier, separate from a Firestore document ID.
  final String id;
  final MapLocationType type;
  final String title;
  final double latitude;
  final double longitude;
  final String description;
  final String address;
  final String category;
  final String operatingHours;
  final String phone;
  final String website;
  final String dietaryStatus;
  final String? photoUrl;

  // Links a business marker back to the existing Business record.
  // Landmarks do not need a businessId.
  final String? businessId;
  final bool active;

  bool get hasValidCoordinates {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  bool get canDisplay => active && hasValidCoordinates;

  // Adapt the shared Business model without modifying it.
  // Missing/invalid coordinates must not create an invented location.
  static MapLocation? fromBusiness(Business business) {
    final latitude = business.latitude;
    final longitude = business.longitude;

    if (latitude == null || longitude == null) {
      return null;
    }

    final location = MapLocation(
      id: 'business:${business.id}',
      type: MapLocationType.business,
      title: business.name,
      latitude: latitude,
      longitude: longitude,
      address: business.address,
      category: business.category,
      businessId: business.id,
      description: business.description?.trim() ?? '',
      operatingHours: business.operatingHours?.trim() ?? '',
      phone: business.phone.trim(),
      website: business.website?.trim() ?? '',
      dietaryStatus: business.dietaryStatus?.trim() ?? '',
      photoUrl: business.photoUrl?.trim(),
      active: business.active,
    );

    return location.hasValidCoordinates ? location : null;
  }
}
