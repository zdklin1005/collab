import '../models/localquest_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

bool hasValidBusinessAdData(Map<String, dynamic> data) {
  bool hasText(String field) {
    final value = data[field];
    return value is String && value.trim().isNotEmpty;
  }

  if (data['type'] != 'ad' ||
      data['status'] != 'active' ||
      !hasText('ownerId') ||
      !hasText('businessId') ||
      !hasText('name') ||
      !hasText('imageUrl')) {
    return false;
  }

  final startDate = data['startDate'];
  final endDate = data['endDate'];

  return startDate is Timestamp &&
      endDate is Timestamp &&
      endDate.toDate().isAfter(startDate.toDate());
}

List<Campaign> availableBusinessAds({
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
    final imageUrl = campaign.imageUrl?.trim() ?? '';

    return campaign.type.trim().toLowerCase() == 'ad' &&
        campaign.status.trim().toLowerCase() == 'active' &&
        campaign.businessId == business.id &&
        campaign.ownerId == business.ownerId &&
        campaign.id.trim().isNotEmpty &&
        campaign.name.trim().isNotEmpty &&
        imageUrl.isNotEmpty &&
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
