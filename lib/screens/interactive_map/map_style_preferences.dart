import 'package:shared_preferences/shared_preferences.dart';

import 'map_style.dart';

class MapStylePreferences {
  static const _storageKey = 'localquest.map.style.v1';

  static final _preferences = SharedPreferencesAsync();
  static Future<void> _pendingWrite = Future<void>.value();

  static Future<MapStyle> load({
    required bool satelliteAvailable,
  }) async {
    // A reopened Discover waits for any earlier save to finish.
    await _pendingWrite;

    final saved = await _preferences.getString(_storageKey);

    if (saved == MapStyle.satellite.name && satelliteAvailable) {
      return MapStyle.satellite;
    }

    // Missing, unknown or unavailable styles safely use Standard.
    return MapStyle.standard;
  }

  static Future<void> save(MapStyle style) {
    // Serialize writes so an older selection cannot overwrite a newer one.
    final operation = _pendingWrite.then((_) {
      return _preferences.setString(_storageKey, style.name);
    });

    // Keep the queue usable after a failure.
    // The original operation still reports the failure to its caller.
    _pendingWrite = operation.catchError((Object _) {});

    return operation;
  }
}