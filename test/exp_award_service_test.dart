import 'package:collab/services/exp_award_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ExpAwardService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = ExpAwardService(firestore: db);

    await db.collection('users').doc('tourist-1').set({
      'role': 'tourist',
      'exp': 45,
      'level': 1,
      'voucherCount': 2,
    });
  });

  Future<ExpAwardReceipt> award({
    String uid = 'tourist-1',
    String source = 'map_exp',
    String sourceId = 'reward-1',
    int amount = 100,
  }) {
    return service.award(
      uid: uid,
      source: source,
      sourceId: sourceId,
      amount: amount,
    );
  }

  test('adds EXP and records the award', () async {
    final result = await award();
    final user = await db.collection('users').doc('tourist-1').get();
    final log = await db
        .collection('users')
        .doc('tourist-1')
        .collection('expLog')
        .doc(result.awardId)
        .get();

    expect(result.alreadyAwarded, isFalse);
    expect(result.previousExp, 45);
    expect(result.newExp, 145);
    expect(user.data()!['exp'], 145);
    expect(user.data()!['level'], 1);
    expect(log.data()!['amount'], 100);
    expect(log.data()!['sourceId'], 'reward-1');
  });

  test('repeated attempts add EXP only once', () async {
    final first = await award();
    final repeated = await award();

    final user = await db.collection('users').doc('tourist-1').get();
    final logs = await db
        .collection('users')
        .doc('tourist-1')
        .collection('expLog')
        .get();

    expect(repeated.awardId, first.awardId);
    expect(repeated.alreadyAwarded, isTrue);
    expect(user.data()!['exp'], 145);
    expect(logs.docs, hasLength(1));
  });

  test('a second marker can award EXP and increase the level', () async {
    await award();
    final second = await award(sourceId: 'reward-2');

    final user = await db.collection('users').doc('tourist-1').get();
    final vouchers = await db
        .collection('users')
        .doc('tourist-1')
        .collection('vouchers')
        .get();

    expect(second.newExp, 245);
    expect(second.previousLevel, 1);
    expect(second.newLevel, 2);
    expect(second.leveledUp, isTrue);
    expect(user.data()!['level'], 2);
    expect(user.data()!['voucherCount'], 2);
    expect(vouchers.docs, isEmpty);
  });

  test('different sources do not collide', () async {
    await award(source: 'map_exp', sourceId: 'activity-1');
    await award(source: 'mission', sourceId: 'activity-1');

    final user = await db.collection('users').doc('tourist-1').get();
    expect(user.data()!['exp'], 245);
  });

  test('reusing an award ID with a different amount is rejected', () async {
    await award();

    await expectLater(award(amount: 200), throwsStateError);

    final user = await db.collection('users').doc('tourist-1').get();
    expect(user.data()!['exp'], 145);
  });

  test('retrying an earlier award does not overwrite later EXP', () async {
    await award();
    await award(sourceId: 'reward-2');
    final repeated = await award();

    final user = await db.collection('users').doc('tourist-1').get();

    expect(repeated.alreadyAwarded, isTrue);
    expect(repeated.newExp, 145); // Historical receipt.
    expect(user.data()!['exp'], 245); // Current account balance.
  });

  test('missing and merchant accounts cannot receive an award', () async {
    await expectLater(award(uid: 'missing-user'), throwsStateError);

    await db.collection('users').doc('merchant-1').set({
      'role': 'merchant',
      'exp': 0,
      'level': 1,
    });

    await expectLater(award(uid: 'merchant-1'), throwsStateError);
  });

  test('non-positive amounts are rejected', () async {
    for (final amount in [0, -1]) {
      await expectLater(award(amount: amount), throwsArgumentError);
    }

    final user = await db.collection('users').doc('tourist-1').get();
    expect(user.data()!['exp'], 45);
  });
}
