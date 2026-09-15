import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/live_business_ad_availability.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 12);

  const business = Business(
    id: 'business-1',
    ownerId: 'merchant-1',
    name: 'Test Cafe',
    category: 'Cafe',
    address: 'Penang',
    phone: '012-3456789',
  );

  Campaign ad({
    required String id,
    String ownerId = 'merchant-1',
    String businessId = 'business-1',
    String type = 'ad',
    String status = 'active',
    String? imageUrl = 'https://example.com/promotion.jpg',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Campaign(
      id: id,
      ownerId: ownerId,
      businessId: businessId,
      name: 'Coffee promotion',
      description: 'Visit us for today’s promotion.',
      type: type,
      status: status,
      imageUrl: imageUrl,
      startDate: startDate ?? now.subtract(const Duration(days: 1)),
      endDate: endDate ?? now.add(const Duration(days: 5)),
    );
  }

  test('includes an active in-date advertisement with an image', () {
    final result = availableBusinessAds(
      business: business,
      campaigns: [ad(id: 'ad-1')],
      now: now,
    );

    expect(result.map((campaign) => campaign.id), ['ad-1']);
  });

  test('excludes campaigns belonging to another business or owner', () {
    final result = availableBusinessAds(
      business: business,
      campaigns: [
        ad(id: 'wrong-business', businessId: 'business-2'),
        ad(id: 'wrong-owner', ownerId: 'merchant-2'),
      ],
      now: now,
    );

    expect(result, isEmpty);
  });

  test('excludes vouchers and advertisements without images', () {
    final result = availableBusinessAds(
      business: business,
      campaigns: [
        ad(id: 'voucher', type: 'voucher'),
        ad(id: 'no-image', imageUrl: null),
        ad(id: 'blank-image', imageUrl: '  '),
      ],
      now: now,
    );

    expect(result, isEmpty);
  });

  test('excludes inactive, scheduled and expired advertisements', () {
    final result = availableBusinessAds(
      business: business,
      campaigns: [
        ad(id: 'inactive', status: 'inactive'),
        ad(id: 'scheduled', status: 'scheduled'),
        ad(
          id: 'expired',
          startDate: now.subtract(const Duration(days: 5)),
          endDate: now.subtract(const Duration(days: 1)),
        ),
      ],
      now: now,
    );

    expect(result, isEmpty);
  });

  test('sorts advertisements by soonest expiry', () {
    final result = availableBusinessAds(
      business: business,
      campaigns: [
        ad(id: 'later', endDate: now.add(const Duration(days: 5))),
        ad(id: 'sooner', endDate: now.add(const Duration(days: 1))),
      ],
      now: now,
    );

    expect(result.map((campaign) => campaign.id), ['sooner', 'later']);
  });
}