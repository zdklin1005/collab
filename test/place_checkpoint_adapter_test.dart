import 'package:collab/models/map_location.dart';
import 'package:collab/services/place_checkpoint_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MapLocation place({
    String? sourceId = 'place-test',
    MapLocationType type = MapLocationType.business,
    String title = 'Test place',
    bool active = true,
    bool approved = true,
    double latitude = 5,
    double longitude = 100,
  }) {
    return MapLocation(
      id: '${type.name}:${sourceId ?? ''}',
      sourceDocumentId: sourceId,
      type: type,
      title: title,
      latitude: latitude,
      longitude: longitude,
      active: active,
      rewardPlacementApproved: approved,
    );
  }

  test('creates a checkpoint from an approved active place', () {
    final checkpoint = derivePlaceCheckpoints([place()]).single;

    expect(checkpoint.id, 'business:place-test');
    expect(checkpoint.locationId, 'place-test');
    expect(checkpoint.locationType, MapLocationType.business);
    expect(checkpoint.latitude, 5);
    expect(checkpoint.longitude, 100);
    expect(checkpoint.canSpawn, isTrue);
  });

  test('business and landmark IDs remain separate', () {
    final checkpoints = derivePlaceCheckpoints([
      place(),
      place(type: MapLocationType.landmark),
    ]);

    expect(checkpoints.map((item) => item.id), [
      'business:place-test',
      'landmark:place-test',
    ]);
  });

  test('inactive or unapproved places do not produce checkpoints', () {
    expect(
      derivePlaceCheckpoints([
        place(sourceId: 'inactive', active: false),
        place(sourceId: 'unapproved', approved: false),
      ]),
      isEmpty,
    );
  });

  test('approval defaults to false', () {
    const location = MapLocation(
      id: 'landmark:default',
      sourceDocumentId: 'default',
      type: MapLocationType.landmark,
      title: 'Test landmark',
      latitude: 5,
      longitude: 100,
    );

    expect(location.rewardPlacementApproved, isFalse);
    expect(derivePlaceCheckpoints([location]), isEmpty);
  });

  test('invalid source IDs and coordinates are rejected', () {
    expect(
      derivePlaceCheckpoints([
        place(sourceId: null),
        place(sourceId: ''),
        place(sourceId: ' '),
        place(sourceId: 'landmarks/test'),
        place(sourceId: '.', latitude: 5),
        place(sourceId: 'bad-latitude', latitude: 91),
        place(sourceId: 'bad-longitude', longitude: double.nan),
        place(sourceId: 'blank-title', title: ' '),
      ]),
      isEmpty,
    );
  });

  test('renaming a place preserves its checkpoint ID', () {
    final before = derivePlaceCheckpoints([place()]).single;
    final after = derivePlaceCheckpoints([
      place(title: 'Renamed place'),
    ]).single;

    expect(after.id, before.id);
    expect(after.locationId, before.locationId);
    expect(after.label, 'Renamed place checkpoint');
  });

  test('output order is stable and the list is read-only', () {
    final a = place(sourceId: 'a');
    final b = place(sourceId: 'b');

    final forward = derivePlaceCheckpoints([a, b]);
    final reversed = derivePlaceCheckpoints([b, a]);

    expect(forward.map((item) => item.id), reversed.map((item) => item.id));
    expect(() => forward.clear(), throwsUnsupportedError);
  });

  test('duplicate eligible parent records are reported', () {
    expect(
      () => derivePlaceCheckpoints([place(), place()]),
      throwsArgumentError,
    );
  });
}
