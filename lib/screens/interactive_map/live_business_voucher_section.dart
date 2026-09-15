import 'package:flutter/material.dart';

import '../../models/localquest_models.dart';
import '../../services/live_business_voucher_availability.dart';

class LiveBusinessVoucherSection extends StatelessWidget {
  const LiveBusinessVoucherSection({
    super.key,
    required this.business,
    required this.campaigns,
    required this.checkedAt,
    this.onSelected,
  });

  final Business business;
  final List<Campaign> campaigns;
  final DateTime checkedAt;
  final ValueChanged<Campaign>? onSelected;

  String _discountLabel(Campaign campaign) {
    if (campaign.discountValue <= 0) {
      return 'See voucher details';
    }

    if (campaign.discountType == 'percentage') {
      return '${campaign.discountValue.toStringAsFixed(0)}% discount';
    }

    return 'RM ${campaign.discountValue.toStringAsFixed(2)} discount';
  }

  @override
  Widget build(BuildContext context) {
    final available = availableDiscoveryVouchers(
      business: business,
      campaigns: campaigns,
      now: checkedAt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available vouchers',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (available.isEmpty)
          const Text(
            'No vouchers available for this business right now.',
            key: ValueKey('no-live-business-vouchers'),
          )
        else
          for (final campaign in available)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                key: ValueKey('live-business-voucher-${campaign.id}'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: Color(0xFF3267D8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      campaign.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (campaign.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(campaign.description.trim()),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _discountLabel(campaign),
                      style: const TextStyle(
                        color: Color(0xFF3267D8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${campaign.quantity - campaign.claims} remaining'),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: ValueKey(
                        'select-live-business-voucher-${campaign.id}',
                      ),
                      onPressed: onSelected == null
                          ? null
                          : () => onSelected!(campaign),
                      child: const Text('View voucher'),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
