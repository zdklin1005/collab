import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:collab/services/demo_business_voucher_claim_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

void main() {
  final now = DateTime.utc(2026, 9, 12, 2);

  const business = Business(
    id: 'business-a',
    ownerId: 'merchant-a',
    name: 'Demo café',
    category: 'Food & Beverage',
    address: 'Test location',
    phone: '',
  );

  MapVoucherOffer offer({
    String id = 'offer-a',
    String businessId = 'business-a',
    int stock = 3,
    DateTime? validFrom,
    DateTime? expiresAt,
  }) {
    return MapVoucherOffer(
      id: id,
      businessId: businessId,
      title: 'Demo café voucher',
      validFrom: validFrom ?? now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(days: 1)),
      remainingStock: stock,
    );
  }

  test('records a claim without consuming stock', () {
    final store = DemoBusinessVoucherClaimStore();
    final selected = offer();

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        business: business,
        offer: selected,
        now: now,
      ),
      DemoBusinessVoucherClaimStatus.recorded,
    );

    final claim = store.claimsFor('tourist-a').single;

    expect(claim.offer.id, selected.id);
    expect(claim.offer.businessId, business.id);
    expect(claim.claimedAt, now);
    expect(selected.remainingStock, 3);
  });

  test('repeated calls record only one claim', () {
    final store = DemoBusinessVoucherClaimStore();

    for (var attempt = 0; attempt < 5; attempt++) {
      expect(
        store.recordDemoClaim(
          touristId: 'tourist-a',
          business: business,
          offer: offer(),
          now: now,
        ),
        attempt == 0
            ? DemoBusinessVoucherClaimStatus.recorded
            : DemoBusinessVoucherClaimStatus.alreadyClaimed,
      );
    }

    expect(store.claimsFor('tourist-a'), hasLength(1));
  });

  test('another tourist can claim the same offer', () {
    final store = DemoBusinessVoucherClaimStore();

    for (final tourist in ['tourist-a', 'tourist-b']) {
      expect(
        store.recordDemoClaim(
          touristId: tourist,
          business: business,
          offer: offer(),
          now: now,
        ),
        DemoBusinessVoucherClaimStatus.recorded,
      );
    }
  });

  test('a different offer from the same business can be claimed', () {
    final store = DemoBusinessVoucherClaimStore();

    for (final id in ['offer-a', 'offer-b']) {
      expect(
        store.recordDemoClaim(
          touristId: 'tourist-a',
          business: business,
          offer: offer(id: id),
          now: now,
        ),
        DemoBusinessVoucherClaimStatus.recorded,
      );
    }

    expect(store.claimsFor('tourist-a'), hasLength(2));
  });

  test('changing dates or restocking does not reset an existing claim', () {
    final store = DemoBusinessVoucherClaimStore();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      business: business,
      offer: offer(),
      now: now,
    );

    final later = now.add(const Duration(days: 30));

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        business: business,
        offer: offer(
          stock: 100,
          validFrom: later,
          expiresAt: later.add(const Duration(days: 1)),
        ),
        now: later,
      ),
      DemoBusinessVoucherClaimStatus.alreadyClaimed,
    );

    expect(store.claimsFor('tourist-a').single.claimedAt, now);
  });

  test('wrong-business, exhausted and expired offers are rejected', () {
    final store = DemoBusinessVoucherClaimStore();

    for (final selected in [
      offer(businessId: 'business-b'),
      offer(stock: 0),
      offer(expiresAt: now),
    ]) {
      expect(
        store.recordDemoClaim(
          touristId: 'tourist-a',
          business: business,
          offer: selected,
          now: now,
        ),
        DemoBusinessVoucherClaimStatus.unavailable,
      );
    }

    expect(store.claimsFor('tourist-a'), isEmpty);
  });

  test('claim history cannot be modified externally', () {
    final store = DemoBusinessVoucherClaimStore();

    expect(() => store.claimsFor('tourist-a').clear(), throwsUnsupportedError);
  });

  test('empty tourist ID is rejected', () {
    expect(
      () => DemoBusinessVoucherClaimStore().recordDemoClaim(
        touristId: ' ',
        business: business,
        offer: offer(),
        now: now,
      ),
      throwsArgumentError,
    );
  });

  test('snapshot restores claims separately for each tourist', () {
    final original = DemoBusinessVoucherClaimStore();

    for (final tourist in ['tourist-a', 'tourist-b']) {
      original.recordDemoClaim(
        touristId: tourist,
        business: business,
        offer: offer(),
        now: now,
      );
    }

    final restored = DemoBusinessVoucherClaimStore.fromSnapshot(
      original.exportSnapshot(),
    );

    for (final tourist in ['tourist-a', 'tourist-b']) {
      final claim = restored.claimsFor(tourist).single;

      expect(claim.offer.id, 'offer-a');
      expect(claim.offer.businessId, business.id);
      expect(claim.claimedAt, now);
      expect(claim.offer.remainingStock, 3);
    }

    expect(restored.claimsFor('tourist-c'), isEmpty);
  });

  test('restored history still blocks an offer with renewed dates', () {
    final original = DemoBusinessVoucherClaimStore();

    original.recordDemoClaim(
      touristId: 'tourist-a',
      business: business,
      offer: offer(),
      now: now,
    );

    final restored = DemoBusinessVoucherClaimStore.fromSnapshot(
      original.exportSnapshot(),
    );

    final later = now.add(const Duration(days: 30));

    expect(
      restored.recordDemoClaim(
        touristId: 'tourist-a',
        business: business,
        offer: offer(
          stock: 100,
          validFrom: later,
          expiresAt: later.add(const Duration(days: 1)),
        ),
        now: later,
      ),
      DemoBusinessVoucherClaimStatus.alreadyClaimed,
    );

    expect(restored.claimsFor('tourist-a').single.claimedAt, now);
  });

  test('empty snapshot restores an empty store', () {
    final restored = DemoBusinessVoucherClaimStore.fromSnapshot(
      DemoBusinessVoucherClaimStore().exportSnapshot(),
    );

    expect(restored.claimsFor('tourist-a'), isEmpty);
  });

  test('malformed and unsupported snapshots are rejected', () {
    for (final source in [
      'not json',
      '{"version":2,"claims":[]}',
      '{"version":1,"claims":[{}]}',
    ]) {
      expect(
        () => DemoBusinessVoucherClaimStore.fromSnapshot(source),
        throwsFormatException,
      );
    }
  });

  test('duplicate history entries are rejected', () {
    final original = DemoBusinessVoucherClaimStore();

    original.recordDemoClaim(
      touristId: 'tourist-a',
      business: business,
      offer: offer(),
      now: now,
    );

    final data = jsonDecode(original.exportSnapshot()) as Map<String, dynamic>;

    final records = data['claims'] as List<dynamic>;
    records.add(records.single);

    expect(
      () => DemoBusinessVoucherClaimStore.fromSnapshot(jsonEncode(data)),
      throwsFormatException,
    );
  });
}
