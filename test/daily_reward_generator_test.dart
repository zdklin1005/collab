import 'package:collab/models/reward_checkpoint.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/map_location.dart';

void main() {
  // 10:00 AM in Malaysia.
  final morning = DateTime.utc(2026, 9, 7, 2);
  final start = DateTime.utc(2026, 9, 6, 16);
  final end = DateTime.utc(2026, 9, 7, 16);

  const checkpoint = RewardCheckpoint(
    id: 'checkpoint-a',
    locationType: MapLocationType.business,
    locationId: 'business-a',
    label: 'Fictional checkpoint',
    latitude: 3,
    longitude: 101,
  );

  const secondCheckpoint = RewardCheckpoint(
    id: 'checkpoint-b',
    locationType: MapLocationType.business,
    locationId: 'business-a',
    label: 'Second fictional checkpoint',
    latitude: 3.001,
    longitude: 101.001,
  );

  MapVoucherOffer offer({
    String id = 'voucher-a',
    String businessId = 'business-a',
    bool active = true,
    bool mapEligible = true,
    int stock = 10,
    DateTime? validFrom,
    DateTime? expiresAt,
  }) {
    return MapVoucherOffer(
      id: id,
      businessId: businessId,
      title: 'Demo merchant voucher',
      validFrom: validFrom ?? start,
      expiresAt: expiresAt ?? end,
      remainingStock: stock,
      active: active,
      mapEligible: mapEligible,
    );
  }

  // Compare values rather than object identities.
  List<Object?> snapshot(List<RewardMarker> rewards) {
    return [
      for (final reward in rewards)
        [
          reward.id,
          reward.checkpointId,
          reward.locationId,
          reward.locationType,
          reward.type,
          reward.title,
          reward.latitude,
          reward.longitude,
          reward.expAmount,
          reward.voucherId,
          reward.availableFrom,
          reward.expiresAt,
        ],
    ];
  }

  test('same day and inputs produce identical rewards', () {
    List<RewardMarker> generate(DateTime time) {
      return DailyRewardGenerator(spawnPercent: 100).generate(
        instant: time,
        checkpoints: [checkpoint, secondCheckpoint],
        activeBusinessIds: {'business-a'},
        voucherOffers: [offer()],
      );
    }

    expect(
      snapshot(generate(morning)),
      snapshot(generate(morning.add(const Duration(hours: 8)))),
    );
  });

  test('Malaysia midnight starts a new generation period', () {
    final generator = DailyRewardGenerator(
      spawnPercent: 100,
      voucherPercent: 0,
    );

    RewardMarker generate(DateTime time) {
      return generator
          .generate(
            instant: time,
            checkpoints: [checkpoint],
            activeBusinessIds: {'business-a'},
          )
          .single;
    }

    final today = generate(morning);
    final beforeMidnight = generate(
      end.subtract(const Duration(microseconds: 1)),
    );
    final tomorrow = generate(end);

    expect(today.availableFrom, start);
    expect(today.expiresAt, end);
    expect(beforeMidnight.id, today.id);
    expect(tomorrow.id, isNot(today.id));
    expect(tomorrow.availableFrom, end);
    expect(today.canDisplayAt(end), isFalse);
  });

  test('input order does not change results', () {
    final generator = DailyRewardGenerator(
      spawnPercent: 100,
      voucherPercent: 100,
    );
    final offers = [offer(), offer(id: 'voucher-b')];

    final first = generator.generate(
      instant: morning,
      checkpoints: [checkpoint, secondCheckpoint],
      activeBusinessIds: {'business-a'},
      voucherOffers: offers,
    );

    final reordered = generator.generate(
      instant: morning,
      checkpoints: [secondCheckpoint, checkpoint],
      activeBusinessIds: {'business-a'},
      voucherOffers: offers.reversed.toList(),
    );

    expect(snapshot(first), snapshot(reordered));
    expect(first.map((r) => r.checkpointId).toSet().length, first.length);
    expect(first.every((r) => r.hasValidDefinition), isTrue);
  });

  test('eligible voucher can be selected', () {
    final reward = DailyRewardGenerator(spawnPercent: 100, voucherPercent: 100)
        .generate(
          instant: morning,
          checkpoints: [checkpoint],
          activeBusinessIds: {'business-a'},
          voucherOffers: [offer()],
        )
        .single;

    expect(reward.type, RewardType.voucher);
    expect(reward.voucherId, 'voucher-a');
    expect(reward.locationId, 'business-a');
    expect(reward.expAmount, 0);
  });

  test('ineligible offers fall back to EXP', () {
    final invalidOffers = [
      offer(active: false),
      offer(mapEligible: false),
      offer(stock: 0),
      offer(businessId: 'another-business'),
      offer(validFrom: start.add(const Duration(hours: 1))),
      offer(expiresAt: end.subtract(const Duration(hours: 1))),
    ];

    final generator = DailyRewardGenerator(
      spawnPercent: 100,
      voucherPercent: 100,
    );

    for (final invalidOffer in invalidOffers) {
      final reward = generator
          .generate(
            instant: morning,
            checkpoints: [checkpoint],
            activeBusinessIds: {'business-a'},
            voucherOffers: [invalidOffer],
          )
          .single;

      expect(reward.type, RewardType.exp);
      expect(reward.expAmount, 100);
      expect(reward.voucherId, isNull);
    }
  });

  test('zero spawn chance or inactive business produces no rewards', () {
    expect(
      DailyRewardGenerator(spawnPercent: 0).generate(
        instant: morning,
        checkpoints: [checkpoint],
        activeBusinessIds: {'business-a'},
      ),
      isEmpty,
    );

    expect(
      DailyRewardGenerator(spawnPercent: 100).generate(
        instant: morning,
        checkpoints: [checkpoint],
        activeBusinessIds: {},
      ),
      isEmpty,
    );
  });

  test('invalid and inactive checkpoints are skipped', () {
    final rewards = DailyRewardGenerator(spawnPercent: 100).generate(
      instant: morning,
      checkpoints: [
        const RewardCheckpoint(
          id: 'inactive',
          locationType: MapLocationType.business,
          locationId: 'business-a',
          label: 'Inactive',
          latitude: 3,
          longitude: 101,
          active: false,
        ),
        const RewardCheckpoint(
          id: 'invalid',
          locationType: MapLocationType.business,
          locationId: 'business-a',
          label: 'Invalid',
          latitude: 91,
          longitude: 101,
        ),
      ],
      activeBusinessIds: {'business-a'},
    );

    expect(rewards, isEmpty);
  });

  test('duplicate checkpoint IDs are rejected', () {
    expect(
      () => DailyRewardGenerator().generate(
        instant: morning,
        checkpoints: [checkpoint, checkpoint],
        activeBusinessIds: {'business-a'},
      ),
      throwsArgumentError,
    );
  });

  test('invalid settings are rejected', () {
    expect(() => DailyRewardGenerator(spawnPercent: 101), throwsArgumentError);
    expect(() => DailyRewardGenerator(voucherPercent: -1), throwsArgumentError);
    expect(() => DailyRewardGenerator(expAmount: 0), throwsArgumentError);
  });

  test('active landmark generates stable EXP without assigning a voucher', () {
    const landmarkCheckpoint = RewardCheckpoint(
      id: 'checkpoint-landmark',
      locationType: MapLocationType.landmark,
      locationId: 'landmark-a',
      label: 'Fictional landmark checkpoint',
      latitude: 3.002,
      longitude: 101.002,
    );

    final generator = DailyRewardGenerator(
      spawnPercent: 100,
      voucherPercent: 100,
    );

    List<RewardMarker> generate(DateTime instant) {
      return generator.generate(
        instant: instant,
        checkpoints: [landmarkCheckpoint],
        activeBusinessIds: {'business-a'},
        activeLandmarkIds: {'landmark-a'},
        voucherOffers: [offer()],
      );
    }

    final first = generate(morning);
    final reward = first.single;

    expect(reward.locationType, MapLocationType.landmark);
    expect(reward.locationId, 'landmark-a');
    expect(reward.checkpointId, landmarkCheckpoint.id);
    expect(reward.latitude, landmarkCheckpoint.latitude);
    expect(reward.longitude, landmarkCheckpoint.longitude);
    expect(reward.type, RewardType.exp);
    expect(reward.expAmount, 100);
    expect(reward.voucherId, isNull);
    expect(reward.hasValidDefinition, isTrue);

    expect(
      snapshot(first),
      snapshot(generate(morning.add(const Duration(hours: 8)))),
    );
  });

  test(
    'landmark requires an active landmark ID, not a matching business ID',
    () {
      const landmarkCheckpoint = RewardCheckpoint(
        id: 'checkpoint-landmark',
        locationType: MapLocationType.landmark,
        locationId: 'shared-id',
        label: 'Fictional landmark checkpoint',
        latitude: 3,
        longitude: 101,
      );

      final rewards = DailyRewardGenerator(spawnPercent: 100).generate(
        instant: morning,
        checkpoints: [landmarkCheckpoint],
        activeBusinessIds: {'shared-id'},
        activeLandmarkIds: {},
      );

      expect(rewards, isEmpty);
    },
  );
}
