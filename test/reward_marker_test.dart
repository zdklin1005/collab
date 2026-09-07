import 'package:collab/models/reward_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed times make these tests repeatable without waiting.
  final start = DateTime.utc(2026, 9, 7, 8);
  final end = start.add(const Duration(hours: 24));
  final during = start.add(const Duration(hours: 1));
  const tick = Duration(microseconds: 1);

  RewardMarker makeReward({
    RewardType type = RewardType.exp,
    String id = 'test-reward',
    String checkpointId = 'test-checkpoint',
    String businessId = 'test-business',
    String title = 'Test reward',
    double latitude = 3,
    double longitude = 101,
    int expAmount = 100,
    String? voucherId,
    bool active = true,
    DateTime? availableFrom,
    DateTime? expiresAt,
  }) {
    return RewardMarker(
      id: id,
      checkpointId: checkpointId,
      businessId: businessId,
      type: type,
      title: title,
      latitude: latitude,
      longitude: longitude,
      expAmount: expAmount,
      voucherId: voucherId,
      active: active,
      availableFrom: availableFrom ?? start,
      expiresAt: expiresAt ?? end,
    );
  }

  for (final type in RewardType.values) {
    group('${type.name} visibility', () {
      RewardMarker validReward({bool active = true}) {
        return makeReward(
          type: type,
          expAmount: type == RewardType.exp ? 100 : 0,
          voucherId: type == RewardType.voucher ? 'test-voucher' : null,
          active: active,
        );
      }

      test('hidden before its start time', () {
        expect(
          validReward().canDisplayAt(start.subtract(tick)),
          isFalse,
        );
      });

      test('visible exactly at start and during availability', () {
        final reward = validReward();

        expect(reward.hasValidDefinition, isTrue);
        expect(reward.canDisplayAt(start), isTrue);
        expect(reward.canDisplayAt(during), isTrue);
        expect(reward.canDisplayAt(end.subtract(tick)), isTrue);
      });

      test('hidden exactly at expiry and afterwards', () {
        final reward = validReward();

        expect(reward.canDisplayAt(end), isFalse);
        expect(reward.canDisplayAt(end.add(tick)), isFalse);
      });

      test('inactive reward stays hidden', () {
        final reward = validReward(active: false);

        // Its data is valid, but its active flag prevents display.
        expect(reward.hasValidDefinition, isTrue);
        expect(reward.canDisplayAt(during), isFalse);
      });
    });
  }

  group('Invalid reward definitions', () {
    test('invalid coordinates prevent display', () {
      final invalidRewards = [
        makeReward(latitude: 90.1),
        makeReward(latitude: -90.1),
        makeReward(longitude: 180.1),
        makeReward(longitude: -180.1),
        makeReward(latitude: double.nan),
        makeReward(longitude: double.nan),
        makeReward(latitude: double.infinity),
        makeReward(longitude: double.negativeInfinity),
      ];

      for (final reward in invalidRewards) {
        expect(reward.hasValidCoordinates, isFalse);
        expect(reward.canDisplayAt(during), isFalse);
      }
    });

    test('invalid EXP data prevents display', () {
      final invalidRewards = [
        makeReward(expAmount: 0),
        makeReward(expAmount: -100),
        makeReward(voucherId: 'unexpected-voucher'),
      ];

      for (final reward in invalidRewards) {
        expect(reward.hasValidRewardData, isFalse);
        expect(reward.canDisplayAt(during), isFalse);
      }
    });

    test('invalid voucher data prevents display', () {
      final invalidRewards = [
        makeReward(type: RewardType.voucher, expAmount: 0),
        makeReward(
          type: RewardType.voucher,
          expAmount: 0,
          voucherId: '   ',
        ),
        makeReward(
          type: RewardType.voucher,
          expAmount: 100,
          voucherId: 'test-voucher',
        ),
        makeReward(
          type: RewardType.voucher,
          expAmount: -1,
          voucherId: 'test-voucher',
        ),
      ];

      for (final reward in invalidRewards) {
        expect(reward.hasValidRewardData, isFalse);
        expect(reward.canDisplayAt(during), isFalse);
      }
    });

    test('missing required identifiers or title prevent display', () {
      final invalidRewards = [
        makeReward(id: ''),
        makeReward(checkpointId: '   '),
        makeReward(businessId: ''),
        makeReward(title: '   '),
      ];

      for (final reward in invalidRewards) {
        expect(reward.hasValidDefinition, isFalse);
        expect(reward.canDisplayAt(during), isFalse);
      }
    });

    test('empty or reversed availability windows prevent display', () {
      final invalidRewards = [
        makeReward(expiresAt: start),
        makeReward(expiresAt: start.subtract(tick)),
      ];

      for (final reward in invalidRewards) {
        expect(reward.hasValidDefinition, isFalse);
        expect(reward.canDisplayAt(start), isFalse);
      }
    });
  });
}