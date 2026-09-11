import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:collab/services/demo_business_voucher_claim_persistence.dart';
import 'package:collab/services/demo_business_voucher_claim_store.dart';

void main() {
  final now = DateTime.utc(2026, 9, 12, 2);

  const business = Business(
    id: 'business-a',
    ownerId: 'merchant-a',
    name: 'Demo café',
    category: 'Food',
    address: 'Demo address',
    phone: '',
  );

  MapVoucherOffer offer() => MapVoucherOffer(
    id: 'offer-a',
    businessId: business.id,
    title: 'Demo voucher',
    validFrom: now.subtract(const Duration(hours: 1)),
    expiresAt: now.add(const Duration(days: 1)),
    remainingStock: 3,
  );

  test('missing storage loads empty history', () async {
    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => null,
      write: (_) async {},
    );

    final store = await persistence.load();

    expect(store.claimsFor('tourist-a'), isEmpty);
  });

  test('saved claims survive a new persistence instance', () async {
    String? saved;

    DemoBusinessVoucherClaimPersistence createPersistence() =>
        DemoBusinessVoucherClaimPersistence.withStorage(
          read: () async => saved,
          write: (value) async {
            saved = value;
          },
        );

    final first = createPersistence();
    final store = await first.load();

    expect(
      store.recordDemoClaim(
        touristId: 'tourist-a',
        business: business,
        offer: offer(),
        now: now,
      ),
      DemoBusinessVoucherClaimStatus.recorded,
    );

    await first.save(store);

    final restored = await createPersistence().load();

    expect(
      restored.hasClaimed(touristId: 'tourist-a', offerId: 'offer-a'),
      isTrue,
    );
    expect(restored.claimsFor('tourist-a').single.claimedAt, now);
    expect(restored.claimsFor('tourist-b'), isEmpty);

    expect(
      restored.recordDemoClaim(
        touristId: 'tourist-a',
        business: business,
        offer: offer(),
        now: now,
      ),
      DemoBusinessVoucherClaimStatus.alreadyClaimed,
    );
  });

  test('saving before loading is blocked', () async {
    var writes = 0;

    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => null,
      write: (_) async {
        writes++;
      },
    );

    await expectLater(
      persistence.save(DemoBusinessVoucherClaimStore()),
      throwsStateError,
    );

    expect(writes, 0);
  });

  test('corrupt history is not overwritten', () async {
    String? saved = 'broken JSON';

    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => saved,
      write: (value) async {
        saved = value;
      },
    );

    await expectLater(persistence.load(), throwsFormatException);

    await expectLater(
      persistence.save(DemoBusinessVoucherClaimStore()),
      throwsStateError,
    );

    expect(saved, 'broken JSON');
  });

  test('a failed write allows a later retry', () async {
    String? saved;
    var failNextWrite = true;

    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => saved,
      write: (value) async {
        if (failNextWrite) {
          failNextWrite = false;
          throw StateError('Simulated storage failure.');
        }
        saved = value;
      },
    );

    final store = await persistence.load();

    store.recordDemoClaim(
      touristId: 'tourist-a',
      business: business,
      offer: offer(),
      now: now,
    );

    await expectLater(persistence.save(store), throwsStateError);
    expect(saved, isNull);

    await persistence.save(store);

    final restored = DemoBusinessVoucherClaimStore.fromSnapshot(saved!);

    expect(
      restored.hasClaimed(touristId: 'tourist-a', offerId: 'offer-a'),
      isTrue,
    );
  });

  test('claim is saved without mutating the original history', () async {
    String? saved;

    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => saved,
      write: (value) async {
        saved = value;
      },
    );

    final original = await persistence.load();

    final result = await persistence.recordAndSave(
      currentStore: original,
      touristId: 'tourist-a',
      business: business,
      offer: offer(),
      now: now,
    );

    expect(result.status, DemoBusinessVoucherClaimStatus.recorded);
    expect(original.claimsFor('tourist-a'), isEmpty);
    expect(result.store.claimsFor('tourist-a'), hasLength(1));

    final restored = DemoBusinessVoucherClaimStore.fromSnapshot(saved!);

    expect(restored.claimsFor('tourist-a'), hasLength(1));
    expect(restored.claimsFor('tourist-a').single.claimedAt, now);
    expect(restored.claimsFor('tourist-a').single.offer.remainingStock, 3);
  });

  test('failed save leaves history unchanged and permits retry', () async {
    String? saved;
    var failNextWrite = true;

    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => saved,
      write: (value) async {
        if (failNextWrite) {
          failNextWrite = false;
          throw StateError('Simulated write failure.');
        }
        saved = value;
      },
    );

    final original = await persistence.load();

    Future<DemoBusinessVoucherSaveResult> attempt() {
      return persistence.recordAndSave(
        currentStore: original,
        touristId: 'tourist-a',
        business: business,
        offer: offer(),
        now: now,
      );
    }

    await expectLater(attempt(), throwsStateError);

    expect(original.claimsFor('tourist-a'), isEmpty);
    expect(saved, isNull);

    final retry = await attempt();

    expect(retry.status, DemoBusinessVoucherClaimStatus.recorded);
    expect(retry.store.claimsFor('tourist-a'), hasLength(1));
    expect(original.claimsFor('tourist-a'), isEmpty);
    expect(saved, isNotNull);
  });

  test('duplicate and expired offers do not trigger extra writes', () async {
    var writes = 0;

    final persistence = DemoBusinessVoucherClaimPersistence.withStorage(
      read: () async => null,
      write: (_) async {
        writes++;
      },
    );

    final original = await persistence.load();
    final selected = offer();

    final first = await persistence.recordAndSave(
      currentStore: original,
      touristId: 'tourist-a',
      business: business,
      offer: selected,
      now: now,
    );

    final duplicate = await persistence.recordAndSave(
      currentStore: first.store,
      touristId: 'tourist-a',
      business: business,
      offer: selected,
      now: now,
    );

    expect(duplicate.status, DemoBusinessVoucherClaimStatus.alreadyClaimed);
    expect(identical(duplicate.store, first.store), isTrue);

    final expired = await persistence.recordAndSave(
      currentStore: first.store,
      touristId: 'tourist-b',
      business: business,
      offer: selected,
      now: selected.expiresAt,
    );

    expect(expired.status, DemoBusinessVoucherClaimStatus.unavailable);
    expect(expired.store.claimsFor('tourist-b'), isEmpty);
    expect(writes, 1);
  });
}
