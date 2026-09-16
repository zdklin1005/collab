import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/business_voucher_claim_check.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 2);

  const business = Business(
    id: 'business-a',
    ownerId: 'merchant-a',
    name: 'Demo café',
    category: 'Food & Beverage',
    address: 'Test location',
    phone: '',
    latitude: 5,
    longitude: 100,
  );

  MapVoucherOffer offer({
    String businessId = 'business-a',
    int stock = 3,
    DateTime? expiresAt,
  }) {
    return MapVoucherOffer(
      id: 'offer-a',
      businessId: businessId,
      title: 'Demo café voucher',
      validFrom: now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
      remainingStock: stock,
    );
  }

  BusinessVoucherClaimStatus check({
    String touristId = 'tourist-a',
    String voucherId = 'offer-a',
    List<MapVoucherOffer>? offers,
    DateTime? checkedAt,
    bool foreground = true,
    bool allowed = true,
    double? latitude = 5,
    double? accuracy = 5,
    DateTime? recordedAt,
    double radius = 50,
    bool alreadyClaimed = false,
  }) {
    return checkBusinessVoucherClaim(
      touristId: touristId,
      business: business,
      selectedVoucherId: voucherId,
      currentOffers: offers ?? [offer()],
      now: checkedAt ?? now,
      appIsForeground: foreground,
      locationAllowed: allowed,
      radiusMeters: radius,
      userLatitude: latitude,
      userLongitude: 100,
      accuracyMeters: accuracy,
      recordedAt: recordedAt ?? checkedAt ?? now,
      hasAlreadyClaimed: alreadyClaimed,
    );
  }

  test('eligible selected offer passes without consuming stock', () {
    final selected = offer();

    expect(check(offers: [selected]), BusinessVoucherClaimStatus.readyForDemo);
    expect(selected.remainingStock, 3);
  });

  test('missing account and background app are rejected', () {
    expect(check(touristId: ''), BusinessVoucherClaimStatus.accountRequired);
    expect(check(foreground: false), BusinessVoucherClaimStatus.appInactive);
  });

  test('missing, wrong-business and ambiguous offers are rejected', () {
    for (final offers in [
      <MapVoucherOffer>[],
      [offer(businessId: 'business-b')],
      [offer(), offer()],
    ]) {
      expect(
        check(offers: offers),
        BusinessVoucherClaimStatus.voucherUnavailable,
      );
    }

    expect(
      check(voucherId: 'unknown-offer'),
      BusinessVoucherClaimStatus.voucherUnavailable,
    );
  });

  test('expiry after preview prevents proceeding', () {
    final expiry = now.add(const Duration(seconds: 10));
    final selected = offer(expiresAt: expiry);

    expect(check(offers: [selected]), BusinessVoucherClaimStatus.readyForDemo);
    expect(
      check(offers: [selected], checkedAt: expiry),
      BusinessVoucherClaimStatus.voucherUnavailable,
    );
  });

  test('updated zero stock overrides earlier availability', () {
    expect(check(), BusinessVoucherClaimStatus.readyForDemo);

    expect(
      check(offers: [offer(stock: 0)]),
      BusinessVoucherClaimStatus.voucherUnavailable,
    );
  });

  test('location loss and missing position are rejected', () {
    expect(
      check(allowed: false),
      BusinessVoucherClaimStatus.locationAccessRequired,
    );
    expect(
      check(latitude: null),
      BusinessVoucherClaimStatus.locationUnavailable,
    );
  });

  test('poor and stale GPS are rejected', () {
    expect(check(accuracy: 60), BusinessVoucherClaimStatus.locationUnreliable);
    expect(
      check(recordedAt: now.subtract(const Duration(seconds: 31))),
      BusinessVoucherClaimStatus.locationUnreliable,
    );
  });

  test('moving away after preview fails the fresh check', () {
    expect(check(), BusinessVoucherClaimStatus.readyForDemo);

    expect(check(latitude: 5.001), BusinessVoucherClaimStatus.outOfRange);
  });

  test('invalid coordinates and radius are rejected', () {
    expect(
      check(latitude: double.nan),
      BusinessVoucherClaimStatus.invalidCoordinates,
    );
    expect(() => check(radius: 0), throwsArgumentError);
  });

  test('previously claimed offer cannot pass eligibility', () {
    expect(
      check(alreadyClaimed: true),
      BusinessVoucherClaimStatus.alreadyClaimed,
    );

    expect(
      check(alreadyClaimed: false),
      BusinessVoucherClaimStatus.readyForDemo,
    );
  });

  test('later dates do not reset previously claimed eligibility', () {
    expect(
      check(alreadyClaimed: true, checkedAt: now.add(const Duration(days: 30))),
      BusinessVoucherClaimStatus.alreadyClaimed,
    );
  });
}
