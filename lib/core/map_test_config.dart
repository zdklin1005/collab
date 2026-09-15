import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class MapTestConfig {
  static const _requested = bool.fromEnvironment('MAP_DEMO_ENABLED');

  static const area = String.fromEnvironment(
    'MAP_TEST_AREA',
    defaultValue: 'Demo',
  );

  static final LatLng? centre = _readCentre();

  static bool get enabled => centre != null;

  static const _forceVoucherRewards = bool.fromEnvironment(
    'MAP_DEMO_FORCE_VOUCHERS',
  );

  static const expiryRewardType = String.fromEnvironment(
    'MAP_DEMO_EXPIRY_REWARD',
  );

  static const _cooldownTestRequested = bool.fromEnvironment(
    'MAP_DEMO_COOLDOWN_TEST',
  );

  static bool get cooldownTestEnabled => enabled && _cooldownTestRequested;

  static bool get expiryRewardEnabled =>
      enabled && (expiryRewardType == 'exp' || expiryRewardType == 'voucher');

  static bool get forceVoucherRewards =>
      kDebugMode && enabled && _forceVoucherRewards;

  static LatLng? _readCentre() {
    // Never enable this preview in profile or release builds.
    if (!kDebugMode || !_requested) return null;

    final latitude = double.tryParse(
      const String.fromEnvironment('MAP_TEST_LAT'),
    );
    final longitude = double.tryParse(
      const String.fromEnvironment('MAP_TEST_LNG'),
    );

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() >= 89 ||
        longitude.abs() >= 179) {
      debugPrint('Map demo disabled: missing or invalid test centre.');
      return null;
    }

    return LatLng(latitude, longitude);
  }
}
