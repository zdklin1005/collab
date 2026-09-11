import '../models/localquest_models.dart';
import 'daily_reward_generator.dart';

/// Filters the supplied business-claim offers.
///
/// Prototype availability only. This does not check tourist eligibility,
/// proximity, previous claims, or live backend stock.
/// It does not issue vouchers or change quantities.
List<MapVoucherOffer> availableBusinessVouchers({
  required Business business,
  required Iterable<MapVoucherOffer> offers,
  required DateTime now,
}) {
  if (!business.active ||
      business.id.trim().isEmpty ||
      business.ownerId.trim().isEmpty) {
    return const [];
  }

  final available = offers.where((offer) {
    return offer.businessId == business.id &&
        offer.id.trim().isNotEmpty &&
        offer.title.trim().isNotEmpty &&
        offer.active &&
        offer.remainingStock > 0 &&
        offer.expiresAt.isAfter(offer.validFrom) &&
        !now.isBefore(offer.validFrom) &&
        now.isBefore(offer.expiresAt);
  }).toList();

  // Present soonest-expiring offers first, with stable ordering.
  available.sort((a, b) {
    final expiryOrder = a.expiresAt.compareTo(b.expiresAt);

    return expiryOrder != 0 ? expiryOrder : a.id.compareTo(b.id);
  });

  return List<MapVoucherOffer>.unmodifiable(available);
}
