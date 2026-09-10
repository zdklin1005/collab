enum MapStyle {
  standard,
  satellite,
}

class MapStyleConfig {
  static const _key = String.fromEnvironment('MAPTILER_API_KEY');

  static bool get satelliteAvailable => _key.trim().isNotEmpty;

  static String label(MapStyle style) {
    return switch (style) {
      MapStyle.standard => 'Standard',
      MapStyle.satellite => 'Satellite',
    };
  }

  static String tileUrl(MapStyle style) {
    return switch (style) {
      MapStyle.standard =>
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      MapStyle.satellite =>
        'https://api.maptiler.com/maps/hybrid/256/{z}/{x}/{y}.jpg'
            '?key=${Uri.encodeQueryComponent(_key.trim())}',
    };
  }
}