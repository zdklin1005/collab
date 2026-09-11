import 'package:flutter/material.dart';

import '../../../models/localquest_models.dart';
import '../../../services/business_voucher_availability.dart';
import '../../../services/daily_reward_generator.dart';

class BusinessVoucherSection extends StatelessWidget {
  const BusinessVoucherSection({
    super.key,
    required this.business,
    required this.offers,
    required this.checkedAt,
    this.onSelected,
  });

  final Business business;
  final List<MapVoucherOffer> offers;
  final DateTime checkedAt;
  final ValueChanged<MapVoucherOffer>? onSelected;

  @override
  Widget build(BuildContext context) {
    final available = availableBusinessVouchers(
      business: business,
      offers: offers,
      now: checkedAt,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business vouchers',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (available.isEmpty)
          const Text('No vouchers available for this business right now.')
        else ...[
          for (final offer in available)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
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
                      offer.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Demo availability: '
                      '${offer.remainingStock} remaining',
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
  key: ValueKey('select-business-voucher-${offer.id}'),
  onPressed: onSelected == null
      ? null
      : () => onSelected!(offer),
  child: Text(
    onSelected == null
        ? 'Claim — coming next'
        : 'Select voucher',
  ),
),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Demo snapshot when opened—not live stock. '
          'No voucher is issued from this preview.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
