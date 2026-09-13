import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'map_test_config.dart';

class MapMovementTestConfig {
  static const _requested = bool.fromEnvironment('MAP_TEST_MOVEMENT_ENABLED');

  static final LatLng? start = _readStart();

  static bool get enabled => start != null;

  // Distance travelled by each arrow-button tap.
  static const double stepMeters = 10;

  static LatLng? _readStart() {
    // Simulated movement is unavailable in profile/release builds.
    if (!kDebugMode || !_requested) return null;

    // Keep this mode separate from the existing mock-data map.
    if (MapTestConfig.enabled) {
      debugPrint(
        'Test movement disabled: turn off MAP_DEMO_ENABLED '
        'to use live Firebase places.',
      );
      return null;
    }

    final latitude = double.tryParse(
      const String.fromEnvironment('MAP_TEST_MOVEMENT_LAT'),
    );
    final longitude = double.tryParse(
      const String.fromEnvironment('MAP_TEST_MOVEMENT_LNG'),
    );

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() >= 89 ||
        longitude.abs() >= 179) {
      debugPrint(
        'Test movement disabled: missing or invalid start coordinates.',
      );
      return null;
    }

    return LatLng(latitude, longitude);
  }
}
