import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/demo_map_claim_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 2);

  RewardMarker makeReward({
    String id = 'test-spawn',
    RewardType type = RewardType.exp,
    bool active = true,
    DateTime? expiresAt,
    String checkpointId = 'test-checkpoint',
    DateTime? availableFrom,
  }) {
    return RewardMarker(
      id: id,
      checkpointId: checkpointId,
      locationType: MapLocationType.business,
      locationId: 'test-business',
      type: type,
      title: 'Demo reward',
      latitude: 5,
      longitude: 100,
      expAmount: type == RewardType.exp ? 100 : 0,
      voucherId: type == RewardType.voucher ? 'test-offer' : null,
      availableFrom: availableFrom ?? now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
      active: active,
    );
  }

  test('records a simulated claim with its reward snapshot', () {
    final store = DemoMapClaimStore();
    final reward = makeReward();

    expect(
      store.recordDemoClaim(touristId: 'tourist-a', reward: reward, now: now),
      DemoMapClaimStatus.recorded,
    );

    final claim = store.claimsFor('tourist-a').single;

    expect(claim.touristId, 'tourist-a');
    expect(claim.reward.id, reward.id);
    expect(claim.reward.expAmount, 100);
    expect(claim.collectedAt, now);
    expect(
      store.hasClaimed(touristId: 'tourist-a', spawnId: reward.id),
      isTrue,
    );
  });

  test('repeated taps record only one claim', () {
    final store = DemoMapClaimStore();
    final reward = makeReward();

    for (var attempt = 0; attempt < 5; attempt++) {
      expect(
        store.recordDemoClaim(touristId: 'tourist-a', reward: reward, now: now),
        attempt == 0
            ? DemoMapClaimStatus.recorded
            : DemoMapClaimStatus.alreadyClaimed,
      );
    }

    expect(store.claimsFor('tourist-a'), hasLength(1));
  });

  test('another tourist can collect the same shared spawn', () {
    final store = DemoMapClaimStore();
    final reward = makeReward();

    for (final touristId in ['tourist-a', 'tourist-b']) {
      expect(
        store.recordDemoClaim(touristId: touristId, reward: reward, now: now),
        DemoMapClaimStatus.recorded,
      );
    }

    expect(store.claimsFor('tourist-a'), hasLength(1));
    expect(store.claimsFor('tourist-b'), hasLength(1));
    expect(store.claimsFor('tourist-c'), isEmpty);
    expect(reward.active, isTrue);
  });

  test('voucher claim records a reference without issuing a voucher', () {
    final store = DemoMapClaimStore();

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: makeReward(type: RewardType.voucher),
        now: now,
      ),
      DemoMapClaimStatus.recorded,
    );

    final claim = store.claimsFor('tourist-a').single;

    expect(claim.reward.type, RewardType.voucher);
    expect(claim.reward.voucherId, 'test-offer');
    expect(claim.reward.expAmount, 0);
  });

  test('inactive and expired rewards are not recorded', () {
    final store = DemoMapClaimStore();

    for (final reward in [
      makeReward(active: false),
      makeReward(expiresAt: now),
    ]) {
      expect(
        store.recordDemoClaim(touristId: 'tourist-a', reward: reward, now: now),
        DemoMapClaimStatus.rewardUnavailable,
      );
    }

    expect(store.claimsFor('tourist-a'), isEmpty);
  });

  test('claim list cannot be modified externally', () {
    final store = DemoMapClaimStore();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    expect(() => store.claimsFor('tourist-a').clear(), throwsUnsupportedError);

    expect(store.claimsFor('tourist-a'), hasLength(1));
  });

  test('a new store does not retain previous claims', () {
    final firstStore = DemoMapClaimStore();

    firstStore.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    expect(DemoMapClaimStore().claimsFor('tourist-a'), isEmpty);
  });

  test('empty tourist ID is rejected', () {
    final store = DemoMapClaimStore();

    expect(
      () => store.recordDemoClaim(
        touristId: '   ',
        reward: makeReward(),
        now: now,
      ),
      throwsArgumentError,
    );
  });

  test('new daily spawn does not bypass the 24-hour cooldown', () {
    final store = DemoMapClaimStore();

    // Malaysia: 11:55 PM, then 12:05 AM the following day.
    final firstTime = DateTime.utc(2026, 9, 10, 15, 55);
    final midnight = DateTime.utc(2026, 9, 10, 16);
    final secondTime = midnight.add(const Duration(minutes: 5));

    final firstReward = makeReward(
      id: 'day-one-spawn',
      availableFrom: firstTime.subtract(const Duration(hours: 1)),
      expiresAt: midnight,
    );

    final secondReward = makeReward(
      id: 'day-two-spawn',
      availableFrom: midnight,
      expiresAt: midnight.add(const Duration(days: 1)),
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: firstReward,
        now: firstTime,
      ),
      DemoMapClaimStatus.recorded,
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: secondReward,
        now: secondTime,
      ),
      DemoMapClaimStatus.checkpointOnCooldown,
    );

    expect(store.claimsFor('tourist-a'), hasLength(1));
    expect(
      store.nextEligibleAt(
        touristId: 'tourist-a',
        checkpointId: 'test-checkpoint',
      ),
      firstTime.add(const Duration(hours: 24)),
    );
  });

  test('new spawn becomes eligible exactly after 24 hours', () {
    final store = DemoMapClaimStore();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    final eligibleAt = now.add(const Duration(hours: 24));

    final nextReward = makeReward(
      id: 'next-spawn',
      availableFrom: now.add(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 48)),
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: nextReward,
        now: eligibleAt.subtract(const Duration(microseconds: 1)),
      ),
      DemoMapClaimStatus.checkpointOnCooldown,
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: nextReward,
        now: eligibleAt,
      ),
      DemoMapClaimStatus.recorded,
    );

    expect(store.claimsFor('tourist-a'), hasLength(2));
    expect(
      store.nextEligibleAt(
        touristId: 'tourist-a',
        checkpointId: 'test-checkpoint',
      ),
      eligibleAt.add(const Duration(hours: 24)),
    );
  });

  test('cooldown does not block another checkpoint or tourist', () {
    final store = DemoMapClaimStore();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: makeReward(
          id: 'other-checkpoint-spawn',
          checkpointId: 'other-checkpoint',
        ),
        now: now,
      ),
      DemoMapClaimStatus.recorded,
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-b',
        reward: makeReward(),
        now: now,
      ),
      DemoMapClaimStatus.recorded,
    );
  });

  test('rejected attempts do not extend the cooldown', () {
    final store = DemoMapClaimStore();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    final nextReward = makeReward(
      id: 'another-spawn',
      expiresAt: now.add(const Duration(days: 2)),
    );

    for (final hours in [1, 5, 23]) {
      expect(
        store.recordDemoClaim(
          touristId: 'tourist-a',
          reward: nextReward,
          now: now.add(Duration(hours: hours)),
        ),
        DemoMapClaimStatus.checkpointOnCooldown,
      );
    }

    expect(
      store.nextEligibleAt(
        touristId: 'tourist-a',
        checkpointId: 'test-checkpoint',
      ),
      now.add(const Duration(hours: 24)),
    );

    expect(store.claimsFor('tourist-a'), hasLength(1));
  });

  test('cooldown applies across EXP and voucher reward types', () {
    final store = DemoMapClaimStore();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        reward: makeReward(id: 'voucher-spawn', type: RewardType.voucher),
        now: now,
      ),
      DemoMapClaimStatus.checkpointOnCooldown,
    );
  });

  test('snapshot restores EXP and voucher claims per tourist', () {
    final original = DemoMapClaimStore();

    original.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    original.recordDemoClaim(
      touristId: 'tourist-b',
      reward: makeReward(type: RewardType.voucher),
      now: now,
    );

    final restored = DemoMapClaimStore.fromSnapshot(original.exportSnapshot());

    final expClaim = restored.claimsFor('tourist-a').single;
    expect(expClaim.reward.type, RewardType.exp);
    expect(expClaim.reward.expAmount, 100);
    expect(expClaim.collectedAt, now);

    final voucherClaim = restored.claimsFor('tourist-b').single;
    expect(voucherClaim.reward.type, RewardType.voucher);
    expect(voucherClaim.reward.voucherId, 'test-offer');
    expect(restored.claimsFor('tourist-c'), isEmpty);
  });

  test('restored history preserves cooldown after original spawn expires', () {
    final original = DemoMapClaimStore();

    original.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    final restored = DemoMapClaimStore.fromSnapshot(original.exportSnapshot());

    expect(
      restored.nextEligibleAt(
        touristId: 'tourist-a',
        checkpointId: 'test-checkpoint',
      ),
      now.add(const Duration(hours: 24)),
    );

    final nextReward = makeReward(
      id: 'next-spawn',
      availableFrom: now.add(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 48)),
    );

    expect(
      restored.recordDemoClaim(
        touristId: 'tourist-a',
        reward: nextReward,
        now: now.add(const Duration(hours: 23)),
      ),
      DemoMapClaimStatus.checkpointOnCooldown,
    );

    expect(
      restored.recordDemoClaim(
        touristId: 'tourist-a',
        reward: nextReward,
        now: now.add(const Duration(hours: 24)),
      ),
      DemoMapClaimStatus.recorded,
    );
  });

  test('restored history still prevents repeated claims', () {
    final original = DemoMapClaimStore();

    original.recordDemoClaim(
      touristId: 'tourist-a',
      reward: makeReward(),
      now: now,
    );

    final restored = DemoMapClaimStore.fromSnapshot(original.exportSnapshot());

    expect(
      restored.recordDemoClaim(
        touristId: 'tourist-a',
        reward: makeReward(),
        now: now,
      ),
      DemoMapClaimStatus.alreadyClaimed,
    );
  });

  test('empty snapshot restores an empty store', () {
    final restored = DemoMapClaimStore.fromSnapshot(
      DemoMapClaimStore().exportSnapshot(),
    );

    expect(restored.claimsFor('tourist-a'), isEmpty);
  });

  test('corrupt and unsupported snapshots are rejected', () {
    for (final source in [
      'not json',
      '{"version":2,"claims":[]}',
      '{"version":1,"claims":[{}]}',
    ]) {
      expect(
        () => DemoMapClaimStore.fromSnapshot(source),
        throwsFormatException,
      );
    }
  });
}
