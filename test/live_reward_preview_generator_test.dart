import 'package:collab/models/localquest_models.dart';
import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/live_reward_preview_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 4);

  const business = Business(
    id: 'business-1',
    ownerId: 'merchant-1',
    name: 'Test cafe',
    category: 'Cafe',
    address: 'Test address',
    phone: '0123456789',
  );

  MapLocation location(MapLocationType type) => MapLocation(
    id: '${type.name}:business-1',
    sourceDocumentId: 'business-1',
    type: type,
    title: 'Test place',
    latitude: 5,
    longitude: 100,
    rewardPlacementApproved: true,
  );

  Campaign offer({
    String id = 'offer-1',
    String method = 'both',
    int claims = 0,
  }) => Campaign(
    id: id,
    ownerId: 'merchant-1',
    businessId: 'business-1',
    name: 'Coffee discount',
    description: 'Test voucher',
    type: 'voucher',
    startDate: DateTime.utc(2026, 9, 1),
    endDate: now.add(const Duration(hours: 1)),
    quantity: 10,
    claims: claims,
    collectionMethod: method,
  );

  List<RewardMarker> generate({
    required List<Campaign> offers,
    int percent = 100,
    MapLocationType type = MapLocationType.landmark,
  }) => generateLiveRewardPreviews(
    places: [location(type)],
    businesses: [business],
    campaigns: offers,
    instant: now,
    spawnPercent: 100,
    voucherPercent: percent,
  );

  test('eligible vouchers work at business and landmark checkpoints', () {
    for (final type in MapLocationType.values) {
      final rewards = generate(offers: [offer()], type: type);

      expect(rewards, isNotEmpty);
      expect(rewards.length, lessThanOrEqualTo(5));
      expect(
        rewards.every((reward) => reward.type == RewardType.voucher),
        isTrue,
      );

      for (final reward in rewards) {
        expect(reward.voucherId, 'offer-1');
        expect(reward.expAmount, 0);
        expect(reward.expiresAt, offer().endDate);
        expect(reward.canDisplayAt(now), isTrue);
      }
    }
  });

  test('missing, discovery-only, and sold-out offers fall back to EXP', () {
    for (final offers in <List<Campaign>>[
      [],
      [offer(method: 'discovery_claim')],
      [offer(claims: 10)],
    ]) {
      expect(
        generate(
          offers: offers,
        ).every((reward) => reward.type == RewardType.exp),
        isTrue,
      );
    }
  });

  test('zero voucher chance preserves EXP', () {
    expect(
      generate(
        offers: [offer()],
        percent: 0,
      ).every((reward) => reward.type == RewardType.exp),
      isTrue,
    );
  });

  test('changing reward type preserves quantities and positions', () {
    final exp = generate(offers: [offer()], percent: 0);
    final vouchers = generate(offers: [offer()]);

    expect(
      vouchers.map((r) => (r.checkpointId, r.latitude, r.longitude)).toList(),
      exp.map((r) => (r.checkpointId, r.latitude, r.longitude)).toList(),
    );
  });

  test('reordering offers does not change selection', () {
    final offers = [offer(), offer(id: 'offer-2')];

    expect(
      generate(offers: offers.reversed.toList()).map((r) => r.id).toList(),
      generate(offers: offers).map((r) => r.id).toList(),
    );
  });

  test('rejects invalid voucher percentages', () {
    expect(() => generate(offers: [], percent: 101), throwsArgumentError);
  });
}
