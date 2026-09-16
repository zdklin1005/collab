import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/live_business_voucher_collection_check.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 12);

  const business = Business(
    id: 'business-1',
    ownerId: 'merchant-1',
    name: 'Test Cafe',
    category: 'Cafe',
    address: 'Penang',
    phone: '012-3456789',
    latitude: 5.4,
    longitude: 100.3,
  );

  final campaign = Campaign(
    id: 'voucher-1',
    ownerId: 'merchant-1',
    businessId: 'business-1',
    name: 'Welcome voucher',
    description: 'Test voucher',
    type: 'voucher',
    status: 'active',
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 5)),
    quantity: 10,
    claims: 0,
    perCustomerLimit: 1,
    voucherType: 'welcome',
    collectionMethod: 'discovery_claim',
  );

  LiveBusinessVoucherCollectionCheck check({
    double? latitude = 5.4,
    double? longitude = 100.3,
    double? accuracy = 5,
    DateTime? recordedAt,
    bool locationAllowed = true,
    bool foreground = true,
    Campaign? selectedCampaign,
  }) {
    return checkLiveBusinessVoucherCollection(
      touristId: 'tourist-1',
      business: business,
      voucherId: 'voucher-1',
      currentCampaigns: [selectedCampaign ?? campaign],
      now: now,
      appIsForeground: foreground,
      locationAllowed: locationAllowed,
      radiusMeters: 50,
      userLatitude: latitude,
      userLongitude: longitude,
      accuracyMeters: accuracy,
      recordedAt: recordedAt ?? now,
    );
  }

  test('allows a current accurate location inside the radius', () {
    final result = check();

    expect(result.status, LiveBusinessVoucherCollectionStatus.ready);
    expect(result.canClaim, isTrue);
    expect(result.distanceMeters, closeTo(0, 0.1));
  });

  test('rejects a location outside the radius', () {
    final result = check(latitude: 5.41, longitude: 100.31);

    expect(result.status, LiveBusinessVoucherCollectionStatus.outOfRange);
    expect(result.canClaim, isFalse);
  });

  test('rejects stale or inaccurate location information', () {
    final stale = check(recordedAt: now.subtract(const Duration(minutes: 2)));

    final inaccurate = check(accuracy: 100);

    expect(
      stale.status,
      LiveBusinessVoucherCollectionStatus.locationUnreliable,
    );
    expect(
      inaccurate.status,
      LiveBusinessVoucherCollectionStatus.locationUnreliable,
    );
  });

  test('rejects missing location access', () {
    final result = check(locationAllowed: false);

    expect(
      result.status,
      LiveBusinessVoucherCollectionStatus.locationAccessRequired,
    );
  });

  test('rejects a map-only voucher', () {
    final mapOnly = Campaign(
      id: campaign.id,
      ownerId: campaign.ownerId,
      businessId: campaign.businessId,
      name: campaign.name,
      description: campaign.description,
      type: campaign.type,
      status: campaign.status,
      startDate: campaign.startDate,
      endDate: campaign.endDate,
      quantity: campaign.quantity,
      claims: campaign.claims,
      perCustomerLimit: campaign.perCustomerLimit,
      voucherType: campaign.voucherType,
      collectionMethod: 'walk_up_collect',
    );

    final result = check(selectedCampaign: mapOnly);

    expect(
      result.status,
      LiveBusinessVoucherCollectionStatus.voucherUnavailable,
    );
  });
}
