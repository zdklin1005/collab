import 'package:collab/models/map_location.dart';
import 'package:collab/services/map_location_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locations = [
    MapLocation(
      id: 'business-b',
      type: MapLocationType.business,
      title: 'Demo Artisan Shop',
      latitude: 3,
      longitude: 101,
    ),
    MapLocation(
      id: 'landmark-a',
      type: MapLocationType.landmark,
      title: 'Demo Heritage Point',
      latitude: 3.001,
      longitude: 101.001,
    ),
    MapLocation(
      id: 'business-a',
      type: MapLocationType.business,
      title: 'Demo Café',
      latitude: 3.002,
      longitude: 101.002,
    ),
    MapLocation(
      id: 'inactive',
      type: MapLocationType.business,
      title: 'Demo Closed Shop',
      latitude: 3,
      longitude: 101,
      active: false,
    ),
    MapLocation(
      id: 'invalid',
      type: MapLocationType.landmark,
      title: 'Demo Invalid Place',
      latitude: 91,
      longitude: 101,
    ),
  ];

  test('Business search ignores case and surrounding spaces', () {
    final results = searchMapLocations(locations, '  ARTISAN  ');

    expect(results.map((item) => item.id), ['business-b']);
  });

  test('Landmarks can be searched by partial name', () {
    final results = searchMapLocations(locations, 'herit');

    expect(results.map((item) => item.id), ['landmark-a']);
  });

  test('Unmatched query returns no results', () {
    expect(searchMapLocations(locations, 'unknown place'), isEmpty);
  });

  test('Empty query lists valid locations alphabetically', () {
    final results = searchMapLocations(locations, '   ');

    expect(
      results.map((item) => item.id),
      ['business-b', 'business-a', 'landmark-a'],
    );
  });

  test('Inactive and invalid locations cannot be selected through search', () {
    expect(searchMapLocations(locations, 'closed'), isEmpty);
    expect(searchMapLocations(locations, 'invalid'), isEmpty);
  });
}