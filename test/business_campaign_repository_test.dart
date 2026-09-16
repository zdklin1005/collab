import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/services/map_repository.dart';

void main() {
  test('business campaign stream includes valid ads and vouchers', () async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 9, 16, 12);

    await firestore.collection('campaigns').doc('ad-1').set({
      'ownerId': 'merchant-1',
      'businessId': 'business-1',
      'name': 'Coffee advertisement',
      'description': 'Promotional advertisement',
      'type': 'ad',
      'status': 'active',
      'imageUrl': 'https://example.com/ad.jpg',
      'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'endDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
    });

    await firestore.collection('campaigns').doc('voucher-1').set({
      'ownerId': 'merchant-1',
      'businessId': 'business-1',
      'name': 'Coffee voucher',
      'description': 'Promotional voucher',
      'type': 'voucher',
      'status': 'active',
      'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      'endDate': Timestamp.fromDate(now.add(const Duration(days: 5))),
      'quantity': 10,
      'claims': 0,
      'perCustomerLimit': 1,
      'voucherType': 'promotional',
      'collectionMethod': 'both',
    });

    await firestore.collection('campaigns').doc('mission-1').set({
      'ownerId': 'merchant-1',
      'businessId': 'business-1',
      'name': 'Not a business campaign',
      'type': 'mission',
      'status': 'active',
    });

    final campaigns = await MapRepository(
      firestore: firestore,
    ).watchActiveBusinessCampaigns().first;

    expect(
      campaigns.map((campaign) => campaign.id),
      containsAll(['ad-1', 'voucher-1']),
    );
    expect(
      campaigns.map((campaign) => campaign.id),
      isNot(contains('mission-1')),
    );
  });

  test('business campaign stream rejects incomplete advertisements', () async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 9, 16, 12);

    await firestore.collection('campaigns').doc('missing-image').set({
      'ownerId': 'merchant-1',
      'businessId': 'business-1',
      'name': 'Incomplete advertisement',
      'type': 'ad',
      'status': 'active',
      'startDate': Timestamp.fromDate(now),
      'endDate': Timestamp.fromDate(now.add(const Duration(days: 1))),
    });

    final campaigns = await MapRepository(
      firestore: firestore,
    ).watchActiveBusinessCampaigns().first;

    expect(campaigns, isEmpty);
  });
}
