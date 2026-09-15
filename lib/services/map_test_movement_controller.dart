import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

enum TestMoveDirection { north, east, south, west }

class MapTestMovementController {
  MapTestMovementController({required LatLng start, this.stepMeters = 10})
    : _start = start,
      _point = start {
    _validatePoint(start);

    if (!stepMeters.isFinite || stepMeters <= 0 || stepMeters > 100) {
      throw ArgumentError.value(
        stepMeters,
        'stepMeters',
        'Must be greater than zero and at most 100 metres.',
      );
    }
  }

  final LatLng _start;
  final double stepMeters;
  LatLng _point;

  LatLng get point => _point;

  LatLng reset() {
    _point = _start;
    return _point;
  }

  LatLng move(TestMoveDirection direction) {
    final bearingDegrees = switch (direction) {
      TestMoveDirection.north => 0.0,
      TestMoveDirection.east => 90.0,
      TestMoveDirection.south => 180.0,
      TestMoveDirection.west => 270.0,
    };

    const earthRadiusMeters = 6371000.0;
    final angularDistance = stepMeters / earthRadiusMeters;
    final bearing = bearingDegrees * math.pi / 180;
    final latitude = _point.latitude * math.pi / 180;
    final longitude = _point.longitude * math.pi / 180;

    final sinNextLatitude =
        math.sin(latitude) * math.cos(angularDistance) +
        math.cos(latitude) * math.sin(angularDistance) * math.cos(bearing);

    final nextLatitude = math.asin(sinNextLatitude.clamp(-1.0, 1.0).toDouble());

    final nextLongitude =
        longitude +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(latitude),
          math.cos(angularDistance) -
              math.sin(latitude) * math.sin(nextLatitude),
        );

    final next = LatLng(
      nextLatitude * 180 / math.pi,
      nextLongitude * 180 / math.pi,
    );

    // Match the supported area of the movement-test configuration.
    // Validate before changing state.
    _validatePoint(next);
    _point = next;
    return _point;
  }

  static void _validatePoint(LatLng point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() >= 89 ||
        point.longitude.abs() >= 179) {
      throw ArgumentError(
        'Test movement requires latitude between -89 and 89 '
        'and longitude between -179 and 179.',
      );
    }
  }
}
