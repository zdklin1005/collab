import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/services/live_business_voucher_claim_service.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 12);

  Future<void> seedData(
    FakeFirebaseFirestore firestore, {
    String collectionMethod = 'discovery_claim',
    String status = 'active',
    int quantity = 10,
    int claims = 0,
  }) async {
    await firestore.collection('businesses').doc('business-1').set({
      'ownerId': 'merchant-1',
      'name': 'Test Cafe',
      'category': 'Cafe',
      'address': 'Penang',
      'phone': '012-3456789',
      'active': true,
      'latitude': 5.4,
      'longitude': 100.3,
    });

    await firestore.collection('campaigns').doc('voucher-1').set({
      'ownerId': 'merchant-1',
      'businessId': 'business-1',
      'name': 'Welcome voucher',
      'description': 'Test voucher',
      'type': 'voucher',
      'status': status,
      'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'endDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
      'quantity': quantity,
      'claims': claims,
      'perCustomerLimit': 1,
      'voucherType': 'welcome',
      'collectionMethod': collectionMethod,
    });
  }

  LiveBusinessVoucherClaimService service(FakeFirebaseFirestore firestore) {
    return LiveBusinessVoucherClaimService(
      firestore: firestore,
      currentUserId: () => 'tourist-1',
      clock: () => now,
    );
  }

  test('records a discovery claim using the shared claim path', () async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);

    final result = await service(
      firestore,
    ).claim(uid: 'tourist-1', businessId: 'business-1', voucherId: 'voucher-1');

    expect(result.status, LiveBusinessVoucherClaimStatus.recorded);
    expect(result.campaign?.id, 'voucher-1');

    final claim = await firestore
        .collection('users')
        .doc('tourist-1')
        .collection('claimedVouchers')
        .doc('voucher-1')
        .get();

    expect(claim.exists, isTrue);
    expect(claim.data()?['voucherId'], 'voucher-1');
    expect(claim.data()?['businessId'], 'business-1');
    expect(claim.data()?['collectionMethod'], 'discovery_claim');
    expect(claim.data()?['redeemed'], isFalse);
  });

  test('the same tourist cannot claim the offer twice', () async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);

    final claimService = service(firestore);

    await claimService.claim(
      uid: 'tourist-1',
      businessId: 'business-1',
      voucherId: 'voucher-1',
    );

    final second = await claimService.claim(
      uid: 'tourist-1',
      businessId: 'business-1',
      voucherId: 'voucher-1',
    );

    expect(second.status, LiveBusinessVoucherClaimStatus.alreadyClaimed);
  });

  test('rejects a map-only voucher', () async {
    final firestore = FakeFirebaseFirestore();

    await seedData(firestore, collectionMethod: 'walk_up_collect');

    final result = await service(
      firestore,
    ).claim(uid: 'tourist-1', businessId: 'business-1', voucherId: 'voucher-1');

    expect(result.status, LiveBusinessVoucherClaimStatus.voucherUnavailable);
  });

  test('rejects an out-of-stock voucher', () async {
    final firestore = FakeFirebaseFirestore();

    await seedData(firestore, quantity: 10, claims: 10);

    final result = await service(
      firestore,
    ).claim(uid: 'tourist-1', businessId: 'business-1', voucherId: 'voucher-1');

    expect(result.status, LiveBusinessVoucherClaimStatus.voucherUnavailable);
  });

  test('rejects a mismatched signed-in account', () async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);

    final claimService = LiveBusinessVoucherClaimService(
      firestore: firestore,
      currentUserId: () => 'another-tourist',
      clock: () => now,
    );

    expect(
      () => claimService.claim(
        uid: 'tourist-1',
        businessId: 'business-1',
        voucherId: 'voucher-1',
      ),
      throwsStateError,
    );
  });
}
