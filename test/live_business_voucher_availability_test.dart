import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/live_business_voucher_availability.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 12);

  const business = Business(
    id: 'business-1',
    ownerId: 'merchant-1',
    name: 'Test Cafe',
    category: 'Cafe',
    address: 'Penang',
    phone: '012-3456789',
    active: true,
  );

  Campaign campaign({
    required String id,
    String ownerId = 'merchant-1',
    String businessId = 'business-1',
    String status = 'active',
    String collectionMethod = 'discovery_claim',
    int quantity = 10,
    int claims = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Campaign(
      id: id,
      ownerId: ownerId,
      businessId: businessId,
      name: 'Test voucher $id',
      description: 'Voucher used for testing.',
      type: 'voucher',
      status: status,
      collectionMethod: collectionMethod,
      quantity: quantity,
      claims: claims,
      perCustomerLimit: 1,
      startDate: startDate ?? now.subtract(const Duration(days: 1)),
      endDate: endDate ?? now.add(const Duration(days: 7)),
    );
  }

  test('includes discovery_claim and both campaigns', () {
    final result = availableDiscoveryVouchers(
      business: business,
      campaigns: [
        campaign(id: 'discovery', collectionMethod: 'discovery_claim'),
        campaign(id: 'both', collectionMethod: 'both'),
      ],
      now: now,
    );

    expect(result.map((item) => item.id), containsAll(['discovery', 'both']));
  });

  test('excludes walk_up_collect campaigns', () {
    final result = availableDiscoveryVouchers(
      business: business,
      campaigns: [
        campaign(id: 'map-only', collectionMethod: 'walk_up_collect'),
      ],
      now: now,
    );

    expect(result, isEmpty);
  });

  test('excludes campaigns belonging to another business or owner', () {
    final result = availableDiscoveryVouchers(
      business: business,
      campaigns: [
        campaign(id: 'wrong-business', businessId: 'business-2'),
        campaign(id: 'wrong-owner', ownerId: 'merchant-2'),
      ],
      now: now,
    );

    expect(result, isEmpty);
  });

  test('excludes inactive, expired and out-of-stock campaigns', () {
    final result = availableDiscoveryVouchers(
      business: business,
      campaigns: [
        campaign(id: 'inactive', status: 'inactive'),
        campaign(
          id: 'expired',
          startDate: now.subtract(const Duration(days: 2)),
          endDate: now.subtract(const Duration(days: 1)),
        ),
        campaign(id: 'out-of-stock', quantity: 5, claims: 5),
      ],
      now: now,
    );

    expect(result, isEmpty);
  });

  test('sorts campaigns by soonest expiry', () {
    final result = availableDiscoveryVouchers(
      business: business,
      campaigns: [
        campaign(id: 'later', endDate: now.add(const Duration(days: 5))),
        campaign(id: 'sooner', endDate: now.add(const Duration(days: 1))),
      ],
      now: now,
    );

    expect(result.map((item) => item.id), ['sooner', 'later']);
  });

  test('inactive business has no available vouchers', () {
    const inactiveBusiness = Business(
      id: 'business-1',
      ownerId: 'merchant-1',
      name: 'Inactive Cafe',
      category: 'Cafe',
      address: 'Penang',
      phone: '012-3456789',
      active: false,
    );

    final result = availableDiscoveryVouchers(
      business: inactiveBusiness,
      campaigns: [campaign(id: 'voucher')],
      now: now,
    );

    expect(result, isEmpty);
  });
}
