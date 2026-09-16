import 'dart:convert';

import '../models/localquest_models.dart';
import '../models/map_location.dart';
import '../models/reward_marker.dart';
import 'live_exp_preview_generator.dart';
import 'map_voucher_preview_eligibility.dart';

int _pick(String seed) {
  var value = 0;
  for (final byte in utf8.encode(seed)) {
    value = (value * 131 + byte) % 2147483647;
  }
  value = (value * 48271) % 2147483647;
  return (value * 48271) % 2147483647;
}

List<RewardMarker> generateLiveRewardPreviews({
  required Iterable<MapLocation> places,
  required Iterable<Business> businesses,
  required Iterable<Campaign> campaigns,
  required DateTime instant,
  int spawnPercent = 80,
  int voucherPercent = 30,
}) {
  if (voucherPercent < 0 || voucherPercent > 100) {
    throw ArgumentError('voucherPercent must be between 0 and 100.');
  }

  final issuers = {for (final business in businesses) business.id: business};

  final eligible = campaigns.where((campaign) {
    return checkMapVoucherPreviewEligibility(
          campaign: campaign,
          issuingBusiness: issuers[campaign.businessId],
          now: instant,
        ) ==
        MapVoucherPreviewEligibility.eligible;
  }).toList()..sort((a, b) => a.id.compareTo(b.id));

  final slots = generateLiveExpPreviews(
    places: places,
    instant: instant,
    spawnPercent: spawnPercent,
  );

  final results = <RewardMarker>[];

  for (final slot in slots) {
    final seed = 'voucher-preview-v1:${slot.id}';

    if (_pick('$seed:type') % 100 >= voucherPercent) {
      results.add(slot);
      continue;
    }

    final offers = eligible.where((campaign) {
      // Business checkpoints use their own merchant's offers.
      // Landmarks may select from the active map-eligible pool.
      return slot.locationType == MapLocationType.landmark ||
          campaign.businessId == slot.locationId;
    }).toList();

    if (offers.isEmpty) {
      results.add(slot);
      continue;
    }

    final offer = offers[_pick('$seed:offer') % offers.length];

    results.add(
      RewardMarker(
        id: '${slot.id}:voucher:${Uri.encodeComponent(offer.id)}',
        checkpointId: slot.checkpointId,
        locationType: slot.locationType,
        locationId: slot.locationId,
        type: RewardType.voucher,
        title: offer.name,
        description: offer.description,
        latitude: slot.latitude,
        longitude: slot.longitude,
        voucherId: offer.id,
        availableFrom: offer.startDate.isAfter(slot.availableFrom)
            ? offer.startDate
            : slot.availableFrom,
        expiresAt: offer.endDate.isBefore(slot.expiresAt)
            ? offer.endDate
            : slot.expiresAt,
      ),
    );
  }

  return List<RewardMarker>.unmodifiable(results);
}
