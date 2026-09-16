import '../models/localquest_models.dart';

List<Campaign> availableDiscoveryVouchers({
  required Business business,
  required Iterable<Campaign> campaigns,
  required DateTime now,
}) {
  if (!business.active ||
      business.id.trim().isEmpty ||
      business.ownerId.trim().isEmpty) {
    return const [];
  }

  final available = campaigns.where((campaign) {
    final method = campaign.collectionMethod.trim().toLowerCase();

    return campaign.type.trim().toLowerCase() == 'voucher' &&
        campaign.status.trim().toLowerCase() == 'active' &&
        campaign.businessId == business.id &&
        campaign.ownerId == business.ownerId &&
        campaign.id.trim().isNotEmpty &&
        campaign.name.trim().isNotEmpty &&
        (method == 'discovery_claim' || method == 'both') &&
        campaign.quantity > 0 &&
        campaign.claims < campaign.quantity &&
        campaign.perCustomerLimit > 0 &&
        campaign.endDate.isAfter(campaign.startDate) &&
        !now.isBefore(campaign.startDate) &&
        now.isBefore(campaign.endDate);
  }).toList();

  available.sort((first, second) {
    final expiryOrder = first.endDate.compareTo(second.endDate);
    return expiryOrder != 0 ? expiryOrder : first.id.compareTo(second.id);
  });

  return List<Campaign>.unmodifiable(available);
}
