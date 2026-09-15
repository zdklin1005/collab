import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/live_map_voucher_claim_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late LiveMapVoucherClaimService service;
  late RewardMarker reward;
  late String? signedInUid;

  final now = DateTime.utc(2026, 9, 16, 10);
  const touristId = 'tourist-1';
  const businessId = 'business-1';
  const voucherId = 'voucher-1';

  setUp(() async {
    db = FakeFirebaseFirestore();
    signedInUid = touristId;

    service = LiveMapVoucherClaimService(
      firestore: db,
      currentUserId: () => signedInUid,
      clock: () => now,
    );

    await db.collection('users').doc(touristId).set({'role': 'tourist'});

    await db.collection('businesses').doc(businessId).set({
      'ownerId': 'merchant-1',
      'name': 'Test Café',
      'category': 'Cafe',
      'address': 'Penang',
      'phone': '',
      'active': true,
      'latitude': 5.4,
      'longitude': 100.3,
    });

    await db.collection('campaigns').doc(voucherId).set({
      'ownerId': 'merchant-1',
      'businessId': businessId,
      'name': '10% Discount',
      'description': 'Test voucher',
      'type': 'voucher',
      'status': 'active',
      'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'endDate': Timestamp.fromDate(now.add(const Duration(days: 1))),
      'claims': 0,
      'quantity': 10,
      'perCustomerLimit': 1,
      'voucherType': 'promotional',
      'collectionMethod': 'both',
    });

    reward = RewardMarker(
      id: 'reward-voucher-1',
      checkpointId: 'business:$businessId',
      locationType: MapLocationType.business,
      locationId: businessId,
      type: RewardType.voucher,
      title: '10% Discount',
      latitude: 5.4,
      longitude: 100.3,
      voucherId: voucherId,
      availableFrom: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
    );
  });

  Future<LiveMapVoucherClaimResult> collect() {
    return service.collect(uid: touristId, reward: reward);
  }

  test('records a real map voucher claim', () async {
    final result = await collect();

    expect(result.status, LiveMapVoucherClaimStatus.recorded);
    expect(result.campaign?.id, voucherId);

    final claim = await db
        .collection('users')
        .doc(touristId)
        .collection('claimedVouchers')
        .doc(voucherId)
        .get();

    expect(claim.exists, isTrue);
    expect(claim.data()?['voucherId'], voucherId);
    expect(claim.data()?['businessId'], businessId);
    expect(claim.data()?['collectionMethod'], 'walk_up_collect');
    expect(claim.data()?['rewardId'], reward.id);
    expect(claim.data()?['redeemed'], isFalse);
  });

  test('same tourist cannot claim the same offer twice', () async {
    final first = await collect();
    final second = await collect();

    expect(first.status, LiveMapVoucherClaimStatus.recorded);
    expect(second.status, LiveMapVoucherClaimStatus.alreadyClaimed);

    final claims = await db
        .collection('users')
        .doc(touristId)
        .collection('claimedVouchers')
        .get();

    expect(claims.docs, hasLength(1));
  });

  test('inactive voucher cannot be claimed', () async {
    await db.collection('campaigns').doc(voucherId).update({
      'status': 'inactive',
    });

    final result = await collect();

    expect(result.status, LiveMapVoucherClaimStatus.voucherUnavailable);
  });

  test('out-of-stock voucher cannot be claimed', () async {
    await db.collection('campaigns').doc(voucherId).update({'claims': 10});

    final result = await collect();

    expect(result.status, LiveMapVoucherClaimStatus.voucherUnavailable);
  });

  test('voucher not enabled for map collection cannot be claimed', () async {
    await db.collection('campaigns').doc(voucherId).update({
      'collectionMethod': 'discovery_claim',
    });

    final result = await collect();

    expect(result.status, LiveMapVoucherClaimStatus.voucherUnavailable);
  });

  test('account mismatch prevents the claim', () async {
    signedInUid = 'tourist-2';

    await expectLater(collect(), throwsA(isA<StateError>()));

    final claim = await db
        .collection('users')
        .doc(touristId)
        .collection('claimedVouchers')
        .doc(voucherId)
        .get();

    expect(claim.exists, isFalse);
  });
}
