import 'dart:convert';

import 'package:flutter/services.dart';

enum MapStyle {
  standard,
  satellite,
}

class MapStyleConfig {
  static String _key = '';

  static Future<void> initialize() async {
    try {
      final contents = await rootBundle.loadString(
        'dev_local/maptiler.json',
      );
      final decoded = jsonDecode(contents);

      if (decoded is Map<String, dynamic>) {
        _key = (decoded['MAPTILER_API_KEY'] as String? ?? '').trim();
      }
    } catch (_) {
      // Satellite remains unavailable when local configuration is absent
      // or invalid. Never log the key or raw configuration contents.
      _key = '';
    }
  }

  static bool get satelliteAvailable => _key.isNotEmpty;

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
            '?key=${Uri.encodeQueryComponent(_key)}',
    };
  }
}