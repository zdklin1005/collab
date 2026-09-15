import 'package:collab/models/map_location.dart';
import 'package:collab/services/map_category_filter.dart';
import 'package:collab/services/map_location_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locations = [
    MapLocation(
      id: 'cafe',
      type: MapLocationType.business,
      title: 'Demo Café',
      category: 'Food & Beverage',
      latitude: 3,
      longitude: 101,
    ),
    MapLocation(
      id: 'crafts',
      type: MapLocationType.business,
      title: 'Demo Artisan Shop',
      category: 'Arts & Crafts',
      latitude: 3,
      longitude: 101,
    ),
    MapLocation(
      id: 'heritage',
      type: MapLocationType.landmark,
      title: 'Demo Heritage Point',
      category: 'Heritage',
      latitude: 3,
      longitude: 101,
    ),
    MapLocation(
      id: 'closed',
      type: MapLocationType.business,
      title: 'Closed Business',
      category: 'Shopping',
      latitude: 3,
      longitude: 101,
      active: false,
    ),
  ];

  test('Categories include only displayable businesses', () {
    expect(availableBusinessCategories(locations), [
      'Arts & Crafts',
      'Food & Beverage',
    ]);
  });

  test('Selected category keeps matching business and landmark', () {
    final results = filterMapLocations(locations, 'Food & Beverage');

    expect(results.map((item) => item.id), ['cafe', 'heritage']);
  });

  test('Category comparison ignores case and surrounding spaces', () {
    final results = filterMapLocations(locations, '  ARTS & CRAFTS  ');

    expect(results.map((item) => item.id), ['crafts', 'heritage']);
  });

  test('Clearing restores all displayable businesses', () {
    final results = filterMapLocations(locations, null);

    expect(results.map((item) => item.id), ['cafe', 'crafts', 'heritage']);
  });

  test('Unknown category does not hide landmarks', () {
    final results = filterMapLocations(locations, 'Unknown category');

    expect(results.map((item) => item.id), ['heritage']);
  });

  test('Search respects the filtered locations', () {
    final filtered = filterMapLocations(locations, 'Food & Beverage');

    expect(searchMapLocations(filtered, 'artisan'), isEmpty);
    expect(searchMapLocations(filtered, 'heritage').single.id, 'heritage');
  });

  const park = MapLocation(
    id: 'park',
    type: MapLocationType.landmark,
    title: 'Demo Park',
    category: 'Park & Garden',
    latitude: 3,
    longitude: 101,
  );

  const mixedLocations = [...locations, park];

  test('Landmark categories exclude businesses', () {
    expect(availableLandmarkCategories(mixedLocations), [
      'Heritage',
      'Park & Garden',
    ]);
  });

  test('Landmark filter preserves all businesses', () {
    final results = filterMapLocations(
      mixedLocations,
      null,
      selectedLandmarkCategory: 'Park & Garden',
    );

    expect(results.map((item) => item.id), ['cafe', 'crafts', 'park']);
  });

  test('Both category filters work independently', () {
    final results = filterMapLocations(
      mixedLocations,
      'Food & Beverage',
      selectedLandmarkCategory: 'Heritage',
    );

    expect(results.map((item) => item.id), ['cafe', 'heritage']);
  });

  test('Landmark comparison ignores case and surrounding spaces', () {
    final results = filterMapLocations(
      mixedLocations,
      null,
      selectedLandmarkCategory: '  PARK & GARDEN  ',
    );

    expect(results.map((item) => item.id), ['cafe', 'crafts', 'park']);
  });

  test('Clearing landmark filter preserves business selection', () {
    final results = filterMapLocations(
      mixedLocations,
      'Food & Beverage',
      selectedLandmarkCategory: '   ',
    );

    expect(results.map((item) => item.id), ['cafe', 'heritage', 'park']);
  });

  test('Unknown landmark category does not hide businesses', () {
    final results = filterMapLocations(
      mixedLocations,
      null,
      selectedLandmarkCategory: 'Unknown category',
    );

    expect(results.map((item) => item.id), ['cafe', 'crafts']);
  });

  test('Search respects landmark filtering', () {
    final filtered = filterMapLocations(
      mixedLocations,
      null,
      selectedLandmarkCategory: 'Park & Garden',
    );

    expect(searchMapLocations(filtered, 'heritage'), isEmpty);
    expect(searchMapLocations(filtered, 'park').single.id, 'park');
  });

  test('Landmark categories ignore inactive and invalid records', () {
    const extraLocations = [
      ...mixedLocations,
      MapLocation(
        id: 'inactive-landmark',
        type: MapLocationType.landmark,
        title: 'Inactive Landmark',
        category: 'Hidden',
        latitude: 3,
        longitude: 101,
        active: false,
      ),
      MapLocation(
        id: 'invalid-landmark',
        type: MapLocationType.landmark,
        title: 'Invalid Landmark',
        category: 'Invalid',
        latitude: 91,
        longitude: 101,
      ),
      MapLocation(
        id: 'another-park',
        type: MapLocationType.landmark,
        title: 'Another Park',
        category: '  park & garden  ',
        latitude: 3,
        longitude: 101,
      ),
    ];

    expect(availableLandmarkCategories(extraLocations), [
      'Heritage',
      'Park & Garden',
    ]);

    final results = filterMapLocations(extraLocations, null);
    expect(results.map((item) => item.id), [
      'cafe',
      'crafts',
      'heritage',
      'park',
      'another-park',
    ]);
  });
}
