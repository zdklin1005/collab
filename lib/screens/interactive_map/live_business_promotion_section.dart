import 'package:flutter/material.dart';

import '../../models/localquest_models.dart';
import '../../services/live_business_ad_availability.dart';
import '../../services/localquest_services.dart';

class LiveBusinessPromotionSection extends StatelessWidget {
  const LiveBusinessPromotionSection({
    super.key,
    required this.business,
    required this.campaigns,
    required this.checkedAt,
    this.compact = false,
  });

  final Business business;
  final List<Campaign> campaigns;
  final DateTime checkedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final available = availableBusinessAds(
      business: business,
      campaigns: campaigns,
      now: checkedAt,
    );

    if (available.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey('no-live-business-promotions'),
      );
    }

    final visible = compact ? available.take(1).toList() : available;
    final hiddenCount = available.length - visible.length;

    for (final campaign in visible) {
      MerchantRepository.instance.recordCampaignView(campaign.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Promotions',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final campaign in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              key: ValueKey('live-business-promotion-${campaign.id}'),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      campaign.imageUrl!.trim(),
                      key: ValueKey(
                        'live-business-promotion-image-${campaign.id}',
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0xFFE5E7EB),
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF6B7280),
                              size: 36,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (campaign.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(campaign.description.trim()),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hiddenCount > 0)
          Text(
            '$hiddenCount more promotion'
            '${hiddenCount == 1 ? '' : 's'} available in business details.',
            key: const ValueKey('more-live-business-promotions'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
      ],
    );
  }
}
