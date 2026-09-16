import 'package:collab/services/map_voucher_history_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MapVoucherHistoryRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = MapVoucherHistoryRepository(firestore: db);
  });

  test('empty voucher history returns an empty set', () async {
    final result = await repository.watchClaimedVoucherIds('tourist-1').first;

    expect(result.data, isEmpty);
  });

  test('voucher claims belong only to their tourist', () async {
    await db
        .collection('users')
        .doc('tourist-1')
        .collection('claimedVouchers')
        .doc('voucher-1')
        .set({'voucherId': 'voucher-1'});

    final first = await repository.watchClaimedVoucherIds('tourist-1').first;
    final second = await repository.watchClaimedVoucherIds('tourist-2').first;

    expect(first.data, {'voucher-1'});
    expect(second.data, isEmpty);
  });

  test('new repository restores a saved voucher claim', () async {
    await db
        .collection('users')
        .doc('tourist-1')
        .collection('claimedVouchers')
        .doc('voucher-1')
        .set({'voucherId': 'voucher-1'});

    final recreated = MapVoucherHistoryRepository(firestore: db);
    final result = await recreated.watchClaimedVoucherIds('tourist-1').first;

    expect(result.data, {'voucher-1'});
  });

  test('malformed voucher history produces an error', () async {
    await db
        .collection('users')
        .doc('tourist-1')
        .collection('claimedVouchers')
        .doc('wrong-id')
        .set({'voucherId': 'voucher-1'});

    await expectLater(
      repository.watchClaimedVoucherIds('tourist-1').first,
      throwsStateError,
    );
  });
}
