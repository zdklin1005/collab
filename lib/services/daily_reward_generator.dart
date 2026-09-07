import 'dart:convert';

import '../models/reward_checkpoint.dart';
import '../models/reward_marker.dart';

// Prototype input only, not a replacement for the team's voucher model.
class MapVoucherOffer {
  const MapVoucherOffer({
    required this.id,
    required this.businessId,
    required this.title,
    required this.validFrom,
    required this.expiresAt,
    required this.remainingStock,
    this.active = true,
    this.mapEligible = true,
  });

  final String id;
  final String businessId;
  final String title;
  final DateTime validFrom;
  final DateTime expiresAt;
  final int remainingStock;
  final bool active;
  final bool mapEligible;

  bool coversDay(DateTime start, DateTime end) {
    return id.trim().isNotEmpty &&
        businessId.trim().isNotEmpty &&
        title.trim().isNotEmpty &&
        active &&
        mapEligible &&
        remainingStock > 0 &&
        !validFrom.isAfter(start) &&
        !expiresAt.isBefore(end);
  }
}

class DailyRewardGenerator {
  DailyRewardGenerator({
    this.spawnPercent = 80,
    this.voucherPercent = 10,
    this.expAmount = 100,
  }) {
    if (spawnPercent < 0 || spawnPercent > 100) {
      throw ArgumentError('spawnPercent must be between 0 and 100.');
    }
    if (voucherPercent < 0 || voucherPercent > 100) {
      throw ArgumentError('voucherPercent must be between 0 and 100.');
    }
    if (expAmount <= 0) {
      throw ArgumentError('expAmount must be positive.');
    }
  }

  final int spawnPercent;
  final int voucherPercent;
  final int expAmount;

  static const _version = 'v1';
  static const _malaysiaOffset = Duration(hours: 8);

  // UTC timestamp representing midnight in Malaysia.
  static DateTime dayStartUtc(DateTime instant) {
    final malaysiaTime = instant.toUtc().add(_malaysiaOffset);

    return DateTime.utc(
      malaysiaTime.year,
      malaysiaTime.month,
      malaysiaTime.day,
    ).subtract(_malaysiaOffset);
  }

  // Explicit repeatable mixing instead of Dart's object hashCode.
  // Development selection only: not cryptographic or cheat-resistant.
  static int _selectionValue(String input) {
    var value = 0;
    for (final byte in utf8.encode(input)) {
      value = (value * 131 + byte) % 2147483647;
    }

    // Final mixing keeps similar checkpoint IDs from simply producing
    // adjacent selection values.
    value = (value * 48271) % 2147483647;
    value = (value * 48271) % 2147483647;
    return value;
  }

  static void _requireUniqueIds(Iterable<String> ids, String label) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        throw ArgumentError('Duplicate $label ID: $id');
      }
    }
  }

  List<RewardMarker> generate({
    required DateTime instant,
    required List<RewardCheckpoint> checkpoints,
    required Set<String> activeBusinessIds,
    List<MapVoucherOffer> voucherOffers = const [],
  }) {
    _requireUniqueIds(checkpoints.map((c) => c.id), 'checkpoint');
    _requireUniqueIds(voucherOffers.map((v) => v.id), 'voucher');

    final start = dayStartUtc(instant);
    final end = start.add(const Duration(days: 1));
    final dayKey = start.toIso8601String();

    final sortedCheckpoints = [...checkpoints]
      ..sort((a, b) => a.id.compareTo(b.id));

    final rewards = <RewardMarker>[];

    for (final checkpoint in sortedCheckpoints) {
      if (!checkpoint.canSpawn ||
          !activeBusinessIds.contains(checkpoint.businessId)) {
        continue;
      }

      // Each checkpoint is selected independently of list order.
      final seed = jsonEncode([_version, dayKey, checkpoint.id]);

      if (_selectionValue('$seed:spawn') % 100 >= spawnPercent) {
        continue;
      }

      final eligibleOffers = voucherOffers.where((offer) {
        return offer.businessId == checkpoint.businessId &&
            offer.coversDay(start, end);
      }).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      MapVoucherOffer? selectedOffer;
      final chooseVoucher =
          _selectionValue('$seed:type') % 100 < voucherPercent;

      if (chooseVoucher && eligibleOffers.isNotEmpty) {
        final index =
            _selectionValue('$seed:offer') % eligibleOffers.length;
        selectedOffer = eligibleOffers[index];
      }

      final isVoucher = selectedOffer != null;

      rewards.add(
        RewardMarker(
          id: 'daily-$_version-${start.millisecondsSinceEpoch}-'
              '${Uri.encodeComponent(checkpoint.id)}',
          checkpointId: checkpoint.id,
          businessId: checkpoint.businessId,
          type: isVoucher ? RewardType.voucher : RewardType.exp,
          title: selectedOffer?.title ?? '$expAmount EXP',
          description: 'Generated development reward. Not redeemable.',
          latitude: checkpoint.latitude,
          longitude: checkpoint.longitude,
          expAmount: isVoucher ? 0 : expAmount,
          voucherId: selectedOffer?.id,
          availableFrom: start,
          expiresAt: end,
        ),
      );
    }

    return List.unmodifiable(rewards);
  }
}