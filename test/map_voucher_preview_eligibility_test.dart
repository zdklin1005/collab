import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/map_voucher_preview_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

Business business({
  String id = 'business-1',
  String ownerId = 'merchant-1',
  bool active = true,
}) {
  return Business(
    id: id,
    ownerId: ownerId,
    name: 'Test cafe',
    category: 'Cafe',
    address: 'Test address',
    phone: '0123456789',
    active: active,
  );
}

Campaign voucher({
  String method = 'both',
  String status = 'active',
  int quantity = 10,
  int claims = 0,
}) {
  return Campaign(
    id: 'voucher-1',
    ownerId: 'merchant-1',
    businessId: 'business-1',
    name: 'Coffee discount',
    description: 'Test voucher',
    type: 'voucher',
    startDate: DateTime.utc(2026, 9, 1),
    endDate: DateTime.utc(2026, 10, 1),
    collectionMethod: method,
    status: status,
    quantity: quantity,
    claims: claims,
    // Redemption restrictions are preserved, not evaluated as claim rules.
    validDays: 'Weekends (Sat–Sun)',
    validHours: '2:00 PM – 5:00 PM',
    dailyQuota: 25,
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 14, 4);

  MapVoucherPreviewEligibility check(Campaign campaign) {
    return checkMapVoucherPreviewEligibility(
      campaign: campaign,
      issuingBusiness: business(),
      now: now,
    );
  }

  test('walk-up and both offers can enter the map preview pool', () {
    for (final method in ['walk_up_collect', 'both']) {
      expect(
        check(voucher(method: method)),
        MapVoucherPreviewEligibility.eligible,
      );
    }
  });

  test('discovery-only and unknown methods cannot enter the map pool', () {
    for (final method in ['discovery_claim', 'unknown']) {
      expect(
        check(voucher(method: method)),
        MapVoucherPreviewEligibility.wrongCollectionMethod,
      );
    }
  });

  test('inactive offers are excluded', () {
    expect(
      check(voucher(status: 'inactive')),
      MapVoucherPreviewEligibility.inactive,
    );
  });

  test('missing, inactive, or mismatched issuing businesses are excluded', () {
    for (final issuer in <Business?>[
      null,
      business(active: false),
      business(id: 'another-business'),
      business(ownerId: 'another-merchant'),
    ]) {
      expect(
        checkMapVoucherPreviewEligibility(
          campaign: voucher(),
          issuingBusiness: issuer,
          now: now,
        ),
        MapVoucherPreviewEligibility.unavailableBusiness,
      );
    }
  });

  test('start is inclusive and expiry is exclusive', () {
    final campaign = voucher();

    MapVoucherPreviewEligibility at(DateTime instant) {
      return checkMapVoucherPreviewEligibility(
        campaign: campaign,
        issuingBusiness: business(),
        now: instant,
      );
    }

    expect(
      at(campaign.startDate.subtract(const Duration(seconds: 1))),
      MapVoucherPreviewEligibility.notStarted,
    );
    expect(at(campaign.startDate), MapVoucherPreviewEligibility.eligible);
    expect(
      at(campaign.endDate.subtract(const Duration(seconds: 1))),
      MapVoucherPreviewEligibility.eligible,
    );
    expect(at(campaign.endDate), MapVoucherPreviewEligibility.expired);
  });

  test('zero stock, sold-out, and oversubscribed offers are excluded', () {
    for (final campaign in [
      voucher(quantity: 0),
      voucher(quantity: 10, claims: 10),
      voucher(quantity: 10, claims: 11),
    ]) {
      expect(check(campaign), MapVoucherPreviewEligibility.outOfStock);
    }
  });

  test('negative counters are rejected', () {
    expect(
      check(voucher(claims: -1)),
      MapVoucherPreviewEligibility.invalidData,
    );
  });
}
