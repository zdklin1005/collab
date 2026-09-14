import 'package:flutter/material.dart';

import '../../../models/map_location.dart';

class MapLocationDetails extends StatelessWidget {
  const MapLocationDetails({
    super.key,
    required this.location,
    required this.onClose,
  });

  final MapLocation location;
  final VoidCallback onClose;

  String _valueOr(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF18233F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF596579),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = location.type == MapLocationType.business;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Icon(
                  isBusiness
                      ? Icons.storefront_outlined
                      : Icons.account_balance_outlined,
                  color: isBusiness
                      ? const Color(0xFF467A45)
                      : const Color(0xFF8055A6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBusiness ? 'Business details' : 'Landmark details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Demo location — fictional information for testing.',
                      style: TextStyle(color: Color(0xFF334466)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    location.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18233F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section(
                    'Category',
                    _valueOr(location.category, 'Not specified.'),
                  ),
                  if (location.dietaryStatus != null &&
                      location.dietaryStatus!.trim().isNotEmpty)
                    _section(
                      'Halal & dietary certification',
                      location.dietaryStatus!.trim(),
                    ),
                  _section(
                    'Address',
                    _valueOr(location.address, 'Address not provided.'),
                  ),
                  _section(
                    isBusiness ? 'About this business' : 'About this landmark',
                    _valueOr(
                      location.description,
                      'Description not provided yet.',
                    ),
                  ),
                  if (isBusiness) ...[
                    _section(
                      'Promotions',
                      'Merchant campaign information is not connected yet.',
                    ),
                    _section(
                      'Business vouchers',
                      'Voucher availability and claiming are not connected yet.',
                    ),
                  ],
                  _section(
                    'Ratings and reviews',
                    'The shared review module is not connected yet.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}