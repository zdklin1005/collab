import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:collab/services/map_exp_claim_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MapExpClaimStore store;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 9, 14, 10);
    db = FakeFirebaseFirestore();
    store = MapExpClaimStore(firestore: db, clock: () => now);

    await db.collection('users').doc('tourist-1').set({
      'role': 'tourist',
      'exp': 45,
      'level': 1,
    });
  });

  RewardMarker reward({int slot = 1}) {
    final start = DailyRewardGenerator.dayStartUtc(now);

    return RewardMarker(
      id: '${start.toIso8601String()}:slot-$slot',
      checkpointId: 'landmark:park-1',
      locationType: MapLocationType.landmark,
      locationId: 'park-1',
      type: RewardType.exp,
      title: '100 EXP',
      latitude: 5,
      longitude: 100,
      expAmount: 100,
      availableFrom: start,
      expiresAt: start.add(const Duration(days: 1)),
    );
  }

  Future<MapExpClaimResult> collect(
    RewardMarker marker, {
    bool simulation = false,
  }) {
    return store.commitValidatedExpClaim(
      uid: 'tourist-1',
      reward: marker,
      simulationActive: simulation,
    );
  }

  Future<int> balance() async {
    final user = await db.collection('users').doc('tourist-1').get();
    return user.data()!['exp'] as int;
  }

  test('records claim, award and cooldown together', () async {
    final result = await collect(reward());

    expect(result.status, MapExpClaimStatus.recorded);
    expect(result.receipt!.newExp, 145);
    expect(await balance(), 145);

    final user = db.collection('users').doc('tourist-1');
    expect((await user.collection('rewardClaims').get()).docs, hasLength(1));
    expect((await user.collection('expLog').get()).docs, hasLength(1));
    expect(
      (await user.collection('checkpointCooldowns').get()).docs,
      hasLength(1),
    );
  });

  test('the same marker cannot award twice', () async {
    final marker = reward();
    await collect(marker);
    final repeated = await collect(marker);

    expect(repeated.status, MapExpClaimStatus.alreadyClaimed);
    expect(await balance(), 145);
  });

  test('another marker in the same batch remains collectable', () async {
    await collect(reward(slot: 1));
    now = now.add(const Duration(hours: 1));

    final second = await collect(reward(slot: 2));

    expect(second.status, MapExpClaimStatus.recorded);
    expect(await balance(), 245);

    final cooldownDoc = await db
        .collection('users')
        .doc('tourist-1')
        .collection('checkpointCooldowns')
        .doc(MapExpClaimStore.cooldownIdFor('landmark:park-1'))
        .get();

    final actual = cooldownDoc.data()!['nextEligibleAt'].toDate() as DateTime;
    final expected = now.add(const Duration(hours: 24));

    expect(actual.isAtSameMomentAs(expected), isTrue);
  });

  test('a new daily batch cannot bypass the 24-hour cooldown', () async {
    await collect(reward());
    now = now.add(const Duration(hours: 18));

    final result = await collect(reward());

    expect(result.status, MapExpClaimStatus.checkpointOnCooldown);
    expect(await balance(), 145);
  });

  test('a new batch can be collected at the cooldown boundary', () async {
    await collect(reward());
    now = now.add(const Duration(hours: 24));

    final result = await collect(reward());

    expect(result.status, MapExpClaimStatus.recorded);
    expect(await balance(), 245);
  });

  test('expired rewards do not award EXP', () async {
    final oldReward = reward();
    now = oldReward.expiresAt;

    final result = await collect(oldReward);

    expect(result.status, MapExpClaimStatus.rewardUnavailable);
    expect(await balance(), 45);
  });

  test('simulated movement cannot commit a claim', () async {
    final result = await collect(reward(), simulation: true);

    expect(result.status, MapExpClaimStatus.simulationBlocked);
    expect(await balance(), 45);

    final claims = await db
        .collection('users')
        .doc('tourist-1')
        .collection('rewardClaims')
        .get();

    expect(claims.docs, isEmpty);
  });
}
