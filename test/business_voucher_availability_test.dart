import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/business_voucher_availability.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 2);

  Business business({bool active = true}) {
    return Business(
      id: 'business-a',
      ownerId: 'merchant-a',
      name: 'Demo café',
      category: 'Food & Beverage',
      address: 'Test location',
      phone: '',
      active: active,
    );
  }

  MapVoucherOffer offer({
    String id = 'offer-a',
    String businessId = 'business-a',
    bool active = true,
    bool mapEligible = true,
    int stock = 10,
    DateTime? validFrom,
    DateTime? expiresAt,
  }) {
    return MapVoucherOffer(
      id: id,
      businessId: businessId,
      title: 'Demo café voucher',
      active: active,
      mapEligible: mapEligible,
      remainingStock: stock,
      validFrom: validFrom ?? now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
    );
  }

  List<MapVoucherOffer> available(
    List<MapVoucherOffer> offers, {
    bool businessActive = true,
  }) {
    return availableBusinessVouchers(
      business: business(active: businessActive),
      offers: offers,
      now: now,
    );
  }

  test('returns only vouchers belonging to the selected business', () {
    final results = available([
      offer(),
      offer(id: 'other-offer', businessId: 'business-b'),
    ]);

    expect(results.single.id, 'offer-a');
  });

  test('inactive business has no available offers', () {
    expect(available([offer()], businessActive: false), isEmpty);
  });

  test('inactive and exhausted offers are unavailable', () {
    expect(
      available([
        offer(id: 'inactive', active: false),
        offer(id: 'empty', stock: 0),
        offer(id: 'invalid-stock', stock: -1),
      ]),
      isEmpty,
    );
  });

  test('validity includes the start but excludes the expiry instant', () {
    expect(available([offer(validFrom: now)]), hasLength(1));

    expect(available([offer(expiresAt: now)]), isEmpty);

    expect(
      available([offer(validFrom: now.add(const Duration(seconds: 1)))]),
      isEmpty,
    );
  });

  test('malformed validity period is rejected', () {
    expect(
      available([
        offer(
          validFrom: now,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      ]),
      isEmpty,
    );
  });

  test('map-spawn eligibility does not control direct business offers', () {
    expect(available([offer(mapEligible: false)]), hasLength(1));
  });

  test('sorts by expiry and then offer ID', () {
    final results = available([
      offer(id: 'later', expiresAt: now.add(const Duration(hours: 2))),
      offer(id: 'b'),
      offer(id: 'a'),
    ]);

    expect(results.map((item) => item.id).toList(), ['a', 'b', 'later']);
  });

  test('empty offers produce an unavailable result', () {
    expect(available([]), isEmpty);
  });

  test('checking availability does not consume stock', () {
    final original = offer(stock: 3);

    available([original]);
    available([original]);

    expect(original.remainingStock, 3);
  });
}
