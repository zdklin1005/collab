import 'package:geolocator/geolocator.dart';

/// Fetches the device's current GPS position directly.
///
/// STUB/TEMPORARY: there's no shared "current position" source from the
/// Interactive Map module yet. Once that exists, swap whatever calls
/// this for that shared source instead — screens consuming a lat/lng
/// don't need to change, just where the number comes from.
///
/// Requires the `geolocator` package:
/// ```yaml
/// dependencies:
///   geolocator: ^13.0.0
/// ```
/// and location permissions declared in AndroidManifest.xml (see setup
/// notes alongside this file).
class DeviceLocationService {
  DeviceLocationService._();
  static final instance = DeviceLocationService._();

  /// Requests permission if needed, then returns the current position.
  /// Throws a plain [Exception] with a user-displayable message on
  /// failure (permission denied, location services off, etc.) — catch
  /// it in the UI to show a retry prompt.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are turned off. Please enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it from app settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
