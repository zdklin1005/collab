import 'package:flutter_test/flutter_test.dart';
import 'package:collab/data/mock_map_data.dart';
import 'package:collab/models/reward_marker.dart';

void main() {
  test('Mock locations have valid coordinates', () {
    final locations = MockMapData.createLocations();

    expect(locations.length, 3);
    expect(locations.every((location) => location.canDisplay), isTrue);
  });

  test('Rewards match their checkpoints and businesses', () {
    final now = DateTime.utc(2026, 9, 7);
    final rewards = MockMapData.createRewards(now);
    final businessIds = MockMapData.businesses.map((b) => b.id).toSet();

    for (final reward in rewards) {
      final checkpoint = MockMapData.checkpoints.singleWhere(
        (checkpoint) => checkpoint.id == reward.checkpointId,
      );

      expect(checkpoint.canSpawn, isTrue);
      expect(businessIds.contains(checkpoint.businessId), isTrue);
      expect(reward.businessId, checkpoint.businessId);
      expect(reward.latitude, checkpoint.latitude);
      expect(reward.longitude, checkpoint.longitude);
      expect(reward.hasValidDefinition, isTrue);
    }

    expect(
      rewards.map((reward) => reward.checkpointId).toSet().length,
      rewards.length,
    );
  });

  test('Only active, unexpired rewards are displayable', () {
    final now = DateTime.utc(2026, 9, 7);
    final rewards = MockMapData.createRewards(now);

    final visible = rewards
        .where((reward) => reward.canDisplayAt(now))
        .toList();

    expect(visible.length, 2);
    expect(
      visible.map((reward) => reward.type),
      containsAll([RewardType.exp, RewardType.voucher]),
    );

    // A reward is no longer available at its exact expiry time.
    expect(visible.first.canDisplayAt(visible.first.expiresAt), isFalse);
  });

  test('Daily mock rewards stay identical within the same Malaysian day', () {
    final morning = DateTime.utc(2026, 9, 7, 2);
    final evening = DateTime.utc(2026, 9, 7, 12);

    final first = MockMapData.createDailyRewards(morning);
    final reopened = MockMapData.createDailyRewards(evening);

    List<Object?> snapshot(List<RewardMarker> rewards) {
      return [
        for (final reward in rewards)
          [
            reward.id,
            reward.checkpointId,
            reward.businessId,
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

    expect(snapshot(first), snapshot(reopened));
    expect(
      first.map((reward) => reward.checkpointId).toSet().length,
      first.length,
    );

    for (final reward in first) {
      expect(reward.hasValidDefinition, isTrue);
      expect(reward.canDisplayAt(morning), isTrue);
      expect(reward.canDisplayAt(reward.expiresAt), isFalse);

      final checkpoint = MockMapData.checkpoints.singleWhere(
        (checkpoint) => checkpoint.id == reward.checkpointId,
      );

      expect(reward.businessId, checkpoint.businessId);
      expect(reward.latitude, checkpoint.latitude);
      expect(reward.longitude, checkpoint.longitude);
    }
  });
}