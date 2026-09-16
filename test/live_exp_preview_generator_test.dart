import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/live_exp_preview_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

MapLocation place({
  String id = 'test-place',
  MapLocationType type = MapLocationType.landmark,
  bool approved = true,
  bool active = true,
}) {
  return MapLocation(
    id: '${type.name}:$id',
    sourceDocumentId: id,
    type: type,
    title: 'Test place',
    latitude: 5,
    longitude: 100,
    active: active,
    rewardPlacementApproved: approved,
  );
}

List<Object> snapshot(List<RewardMarker> rewards) => [
  for (final reward in rewards)
    (
      reward.id,
      reward.checkpointId,
      reward.latitude,
      reward.longitude,
      reward.availableFrom,
      reward.expiresAt,
    ),
];

void main() {
  final morning = DateTime.utc(2026, 9, 14, 1);

  test('both place types produce one to five nearby EXP previews', () {
    final rewards = generateLiveExpPreviews(
      places: [
        place(type: MapLocationType.business),
        place(type: MapLocationType.landmark),
      ],
      instant: morning,
      spawnPercent: 100,
    );

    for (final checkpointId in ['business:test-place', 'landmark:test-place']) {
      final group = rewards
          .where((reward) => reward.checkpointId == checkpointId)
          .toList();

      expect(group.length, inInclusiveRange(1, 5));

      for (final reward in group) {
        final metres = const Distance().as(
          LengthUnit.Meter,
          const LatLng(5, 100),
          LatLng(reward.latitude, reward.longitude),
        );

        expect(metres, inInclusiveRange(4.9, 15.1));
        expect(reward.type, RewardType.exp);
        expect(reward.expAmount, 100);
        expect(reward.voucherId, isNull);
        expect(reward.locationId, 'test-place');
        expect(reward.canDisplayAt(morning), isTrue);
      }
    }

    expect(rewards.map((reward) => reward.id).toSet().length, rewards.length);
  });

  test('quantity varies across places without exceeding five', () {
    final places = List.generate(100, (index) => place(id: 'place-$index'));

    final rewards = generateLiveExpPreviews(
      places: places,
      instant: morning,
      spawnPercent: 100,
    );

    final counts = <String, int>{};
    for (final reward in rewards) {
      counts.update(
        reward.checkpointId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    expect(counts, hasLength(100));
    expect(counts.values.every((count) => count >= 1 && count <= 5), isTrue);
    expect(counts.values.toSet().length, greaterThan(1));
  });

  test('unapproved and inactive places produce no rewards', () {
    expect(
      generateLiveExpPreviews(
        places: [
          place(id: 'unapproved', approved: false),
          place(id: 'inactive', active: false),
        ],
        instant: morning,
        spawnPercent: 100,
      ),
      isEmpty,
    );
  });

  test('same day and reordered places preserve IDs and coordinates', () {
    final places = [place(id: 'first'), place(id: 'second')];

    final first = generateLiveExpPreviews(
      places: places,
      instant: morning,
      spawnPercent: 100,
    );

    final later = generateLiveExpPreviews(
      places: places.reversed,
      instant: DateTime.utc(2026, 9, 14, 15, 59),
      spawnPercent: 100,
    );

    expect(snapshot(later), snapshot(first));
  });

  test('adding another place does not reroll existing rewards', () {
    final first = generateLiveExpPreviews(
      places: [place()],
      instant: morning,
      spawnPercent: 100,
    );

    final expanded = generateLiveExpPreviews(
      places: [
        place(),
        place(id: 'another-place'),
      ],
      instant: morning,
      spawnPercent: 100,
    );

    expect(
      snapshot(
        expanded
            .where((reward) => reward.checkpointId == 'landmark:test-place')
            .toList(),
      ),
      snapshot(first),
    );
  });

  test('Malaysia midnight replaces daily IDs and expires old rewards', () {
    final midnight = DateTime.utc(2026, 9, 14, 16);

    final before = generateLiveExpPreviews(
      places: [place()],
      instant: midnight.subtract(const Duration(minutes: 1)),
      spawnPercent: 100,
    );

    final after = generateLiveExpPreviews(
      places: [place()],
      instant: midnight,
      spawnPercent: 100,
    );

    expect(
      before
          .map((reward) => reward.id)
          .toSet()
          .intersection(after.map((reward) => reward.id).toSet()),
      isEmpty,
    );

    expect(before.every((reward) => !reward.canDisplayAt(midnight)), isTrue);
    expect(after.every((reward) => reward.canDisplayAt(midnight)), isTrue);
    expect(after.first.availableFrom, before.first.expiresAt);
  });

  test('zero spawn chance produces no previews', () {
    expect(
      generateLiveExpPreviews(
        places: [place()],
        instant: morning,
        spawnPercent: 0,
      ),
      isEmpty,
    );
  });
}
