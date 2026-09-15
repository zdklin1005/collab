import 'package:flutter/material.dart';

import '../../../models/map_location.dart';

class MapLocationDetails extends StatelessWidget {
  const MapLocationDetails({
    super.key,
    required this.location,
    required this.onClose,
    this.voucherSection,
    this.isDemo = false,
  });

  final MapLocation location;
  final VoidCallback onClose;
  final Widget? voucherSection;
  final bool isDemo;

  String _valueOr(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  Future<void> _openBusinessPhoto(BuildContext context, String url) async {
    // Prevent repeated taps from opening stacked viewers.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (viewerContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          location.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close photo',
                        color: Colors.white,
                        onPressed: () => Navigator.of(viewerContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: SizedBox.expand(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        semanticLabel: 'Photo of ${location.title}',
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'Photo unavailable',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Pinch to zoom · Drag to explore',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Widget _photoPlaceholder(String message) {
    return ColoredBox(
      color: const Color(0xFFEDF2F7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 40,
                color: Color(0xFF596579),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF596579)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _businessPhoto(BuildContext context) {
    final url = location.photoUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    final validUrl =
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: !validUrl
            ? _photoPlaceholder(
                url.isEmpty ? 'No business photo yet' : 'Photo unavailable',
              )
            : Tooltip(
                message: 'View full photo',
                child: Semantics(
                  button: true,
                  label: 'View full photo of ${location.title}',
                  child: GestureDetector(
                    onTap: () => _openBusinessPhoto(context, url),
                    child: Image.network(
                      url,
                      key: ValueKey(url),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: 'Photo of ${location.title}',
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return const ColoredBox(
                          color: Color(0xFFEDF2F7),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _photoPlaceholder('Photo unavailable');
                      },
                    ),
                  ),
                ),
              ),
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
                  if (isDemo) ...[
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
                  ],
                  if (isBusiness) ...[
                    _businessPhoto(context),
                    const SizedBox(height: 18),
                  ],
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
                  if (location.dietaryStatus.trim().isNotEmpty)
                    _section(
                      'Halal & dietary certification',
                      location.dietaryStatus.trim(),
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
                      'Operating hours',
                      _valueOr(location.operatingHours, 'Hours not provided.'),
                    ),
                    if (location.phone.trim().isNotEmpty)
                      _section('Contact number', location.phone.trim()),
                    if (location.website.trim().isNotEmpty)
                      _section(
                        'Website / social link',
                        location.website.trim(),
                      ),
                    _section(
                      'Promotions',
                      'Merchant campaign information is not connected yet.',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child:
                          voucherSection ??
                          _section(
                            'Business vouchers',
                            'Voucher availability is not connected for this business.',
                          ),
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
