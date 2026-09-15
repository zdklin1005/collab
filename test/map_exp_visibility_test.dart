import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:collab/services/map_exp_history_repository.dart';
import 'package:collab/services/map_exp_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 10);
  final batch = DailyRewardGenerator.dayStartUtc(now);
  final expiry = now.add(const Duration(hours: 1));

  RewardMarker marker(
    String id, {
    String checkpointId = 'landmark:park',
    RewardType type = RewardType.exp,
  }) {
    return RewardMarker(
      id: id,
      checkpointId: checkpointId,
      locationType: MapLocationType.landmark,
      locationId: 'park',
      type: type,
      title: type == RewardType.exp ? '100 EXP' : 'Test voucher',
      latitude: 5,
      longitude: 100,
      availableFrom: batch,
      expiresAt: batch.add(const Duration(days: 1)),
      expAmount: type == RewardType.exp ? 100 : 0,
      voucherId: type == RewardType.voucher ? 'offer-1' : null,
    );
  }

  MapCheckpointCooldown cooldown({required DateTime savedBatch}) {
    return MapCheckpointCooldown(
      checkpointId: 'landmark:park',
      batchStart: savedBatch,
      nextEligibleAt: expiry,
    );
  }

  List<String> visible(
    List<RewardMarker> rewards, {
    Set<String> claimed = const {},
    Map<String, MapCheckpointCooldown> cooldowns = const {},
    DateTime? at,
  }) {
    return filterMapExpHistory(
      rewards: rewards,
      claimedRewardIds: claimed,
      cooldowns: cooldowns,
      now: at ?? now,
    ).map((reward) => reward.id).toList();
  }

  test('empty history preserves available EXP markers', () {
    expect(
      visible([marker('one'), marker('two')]),
      ['one', 'two'],
    );
  });

  test('claimed marker hides but same-batch sibling remains', () {
    expect(
      visible(
        [marker('one'), marker('two')],
        claimed: {'one'},
        cooldowns: {
          'landmark:park': cooldown(savedBatch: batch),
        },
      ),
      ['two'],
    );
  });

  test('previous-batch cooldown blocks only its checkpoint', () {
    expect(
      visible(
        [
          marker('blocked'),
          marker('other', checkpointId: 'landmark:other'),
        ],
        cooldowns: {
          'landmark:park': cooldown(
            savedBatch: batch.subtract(const Duration(days: 1)),
          ),
        },
      ),
      ['other'],
    );
  });

  test('new batch becomes visible at exact cooldown expiry', () {
    expect(
      visible(
        [marker('new')],
        at: expiry,
        cooldowns: {
          'landmark:park': cooldown(
            savedBatch: batch.subtract(const Duration(days: 1)),
          ),
        },
      ),
      ['new'],
    );
  });

  test('expired rewards remain hidden', () {
    expect(
      visible(
        [marker('expired')],
        at: batch.add(const Duration(days: 1)),
      ),
      isEmpty,
    );
  });

  test('EXP history filtering leaves voucher previews unchanged', () {
    expect(
      visible(
        [marker('voucher', type: RewardType.voucher)],
        cooldowns: {
          'landmark:park': cooldown(
            savedBatch: batch.subtract(const Duration(days: 1)),
          ),
        },
      ),
      ['voucher'],
    );
  });

  test('filtering does not remove items from the input list', () {
    final rewards = [marker('one'), marker('two')];

    visible(rewards, claimed: {'one'});

    expect(rewards.map((reward) => reward.id), ['one', 'two']);
  });
}