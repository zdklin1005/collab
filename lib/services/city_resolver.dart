import 'package:geocoding/geocoding.dart';

/// Resolves a human-readable city name from GPS coordinates.
///
/// Requires the `geocoding` package:
/// ```yaml
/// dependencies:
///   geocoding: ^3.0.0
/// ```
/// Uses the device's native geocoder — no API key needed, but does
/// require location permission to already be granted (same permission
/// your GPS/location code elsewhere in the app already needs).
class CityResolver {
  CityResolver._();
  static final instance = CityResolver._();

  /// Returns the city/locality name for the given coordinates, or null
  /// if it can't be resolved (e.g. no network/geocoder data for that
  /// area, or permissions not granted).
  Future<String?> resolveCity(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      // `locality` is usually the city; some regions populate
      // `subAdministrativeArea` instead when `locality` is empty.
      final city = placemark.locality?.trim();
      if (city != null && city.isNotEmpty) return city;

      final fallback = placemark.subAdministrativeArea?.trim();
      return (fallback != null && fallback.isNotEmpty) ? fallback : null;
    } catch (_) {
      // Geocoding can throw on unsupported platforms, missing
      // permissions, or no connectivity — treat all as "unknown city"
      // rather than crashing mission generation.
      return null;
    }
  }
}
