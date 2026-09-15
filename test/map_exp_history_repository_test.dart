import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collab/services/map_exp_claim_store.dart';
import 'package:collab/services/map_exp_history_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MapExpHistoryRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = MapExpHistoryRepository(firestore: db);
  });

  test('empty history returns empty collections', () async {
    final claims = await repository.watchClaimedRewardIds('tourist-1').first;
    final cooldowns = await repository
        .watchCheckpointCooldowns('tourist-1')
        .first;

    expect(claims.data, isEmpty);
    expect(cooldowns.data, isEmpty);
  });

  test('claims belong to the requested tourist only', () async {
    const rewardId = 'reward-1';

    await db
        .collection('users')
        .doc('tourist-1')
        .collection('rewardClaims')
        .doc(MapExpClaimStore.claimIdFor(rewardId))
        .set({'type': 'exp', 'rewardId': rewardId});

    final first = await repository.watchClaimedRewardIds('tourist-1').first;
    final second = await repository.watchClaimedRewardIds('tourist-2').first;

    expect(first.data, {rewardId});
    expect(second.data, isEmpty);
  });

  test('a new reader restores the saved claim', () async {
    const rewardId = 'saved-reward';

    await db
        .collection('users')
        .doc('tourist-1')
        .collection('rewardClaims')
        .doc(MapExpClaimStore.claimIdFor(rewardId))
        .set({'type': 'exp', 'rewardId': rewardId});

    final recreated = MapExpHistoryRepository(firestore: db);
    final result = await recreated.watchClaimedRewardIds('tourist-1').first;

    expect(result.data, {rewardId});
  });

  test(
    'cooldown allows same batch but blocks a new batch until expiry',
    () async {
      const checkpointId = 'landmark:park-1';
      final batchStart = DateTime.utc(2026, 9, 14, 16);
      final nextEligible = DateTime.utc(2026, 9, 16, 10);

      await db
          .collection('users')
          .doc('tourist-1')
          .collection('checkpointCooldowns')
          .doc(MapExpClaimStore.cooldownIdFor(checkpointId))
          .set({
            'checkpointId': checkpointId,
            'batchStart': Timestamp.fromDate(batchStart),
            'nextEligibleAt': Timestamp.fromDate(nextEligible),
          });

      final result = await repository
          .watchCheckpointCooldowns('tourist-1')
          .first;
      final cooldown = result.data[checkpointId]!;
      final beforeExpiry = nextEligible.subtract(const Duration(minutes: 1));
      final nextBatch = batchStart.add(const Duration(days: 1));

      expect(
        cooldown.blocksBatch(
          candidateBatchStart: batchStart.toLocal(),
          now: beforeExpiry,
        ),
        isFalse,
      );
      expect(
        cooldown.blocksBatch(candidateBatchStart: nextBatch, now: beforeExpiry),
        isTrue,
      );
      expect(
        cooldown.blocksBatch(candidateBatchStart: nextBatch, now: nextEligible),
        isFalse,
      );
    },
  );

  test('malformed claim produces an error instead of empty history', () async {
    await db
        .collection('users')
        .doc('tourist-1')
        .collection('rewardClaims')
        .doc('wrong-document-id')
        .set({'type': 'exp', 'rewardId': 'reward-1'});

    await expectLater(
      repository.watchClaimedRewardIds('tourist-1').first,
      throwsStateError,
    );
  });

  test('malformed cooldown produces an error', () async {
    const checkpointId = 'landmark:park-1';

    await db
        .collection('users')
        .doc('tourist-1')
        .collection('checkpointCooldowns')
        .doc(MapExpClaimStore.cooldownIdFor(checkpointId))
        .set({
          'checkpointId': checkpointId,
          'batchStart': 'not-a-timestamp',
          'nextEligibleAt': Timestamp.now(),
        });

    await expectLater(
      repository.watchCheckpointCooldowns('tourist-1').first,
      throwsStateError,
    );
  });

  test('invalid user IDs are rejected', () {
    expect(() => repository.watchClaimedRewardIds(''), throwsArgumentError);
    expect(
      () => repository.watchCheckpointCooldowns('users/another-user'),
      throwsArgumentError,
    );
  });
}
