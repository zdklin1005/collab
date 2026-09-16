import 'package:flutter/material.dart';

import '../../models/map_location.dart';

class MapLocationDetails extends StatelessWidget {
  const MapLocationDetails({
    super.key,
    required this.location,
    required this.onClose,
    this.onNavigate,
    this.promotionSection,
    this.voucherSection,
    this.isDemo = false,
  });

  final MapLocation location;
  final VoidCallback onClose;
  final VoidCallback? onNavigate;
  final Widget? promotionSection;
  final Widget? voucherSection;
  final bool isDemo;

  String _valueOr(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  Future<void> _openLocationPhoto(BuildContext context, String url) async {
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
                        onPressed: () {
                          Navigator.of(viewerContext).pop();
                        },
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

  Widget _section(
    String title,
    String content, {
    Color titleColor = const Color(0xFF18233F),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
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

  Widget _categoryCard({
    required String label,
    required IconData icon,
    required Color accentColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _valueOr(location.category, 'Not specified.'),
                  style: const TextStyle(
                    color: Color(0xFF18233F),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required Color iconBackground,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF253047),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationCard({
    required String title,
    required List<Widget> rows,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                rows[index],
                if (index < rows.length - 1)
                  const Divider(height: 1, indent: 51),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _businessCategoryCard() {
    return _categoryCard(
      label: 'Business category',
      icon: Icons.storefront_outlined,
      accentColor: const Color(0xFF467A45),
      backgroundColor: const Color(0xFFEDF6EC),
    );
  }

  Widget _landmarkCategoryCard() {
    return _categoryCard(
      label: 'Landmark category',
      icon: Icons.account_balance_outlined,
      accentColor: const Color(0xFF8055A6),
      backgroundColor: const Color(0xFFF3ECFA),
    );
  }

  Widget _businessInformationCard() {
    const accentColor = Color(0xFF467A45);
    const iconBackground = Color(0xFFEDF6EC);

    final rows = <Widget>[
      _detailRow(
        icon: Icons.location_on_outlined,
        label: 'Address',
        value: _valueOr(location.address, 'Address not provided.'),
        accentColor: accentColor,
        iconBackground: iconBackground,
      ),
      _detailRow(
        icon: Icons.schedule_outlined,
        label: 'Operating hours',
        value: _valueOr(location.operatingHours, 'Hours not provided.'),
        accentColor: accentColor,
        iconBackground: iconBackground,
      ),
      if (location.phone.trim().isNotEmpty)
        _detailRow(
          icon: Icons.phone_outlined,
          label: 'Contact number',
          value: location.phone.trim(),
          accentColor: accentColor,
          iconBackground: iconBackground,
        ),
      if (location.website.trim().isNotEmpty)
        _detailRow(
          icon: Icons.language_outlined,
          label: 'Website / social link',
          value: location.website.trim(),
          accentColor: accentColor,
          iconBackground: iconBackground,
        ),
      if (location.dietaryStatus.trim().isNotEmpty)
        _detailRow(
          icon: Icons.verified_outlined,
          label: 'Halal & dietary certification',
          value: location.dietaryStatus.trim(),
          accentColor: accentColor,
          iconBackground: iconBackground,
        ),
    ];

    return _informationCard(
      title: 'Business information',
      rows: rows,
      accentColor: accentColor,
    );
  }

  Widget _landmarkInformationCard() {
    const accentColor = Color(0xFF8055A6);
    const iconBackground = Color(0xFFF3ECFA);

    return _informationCard(
      title: 'Landmark information',
      accentColor: accentColor,
      rows: [
        _detailRow(
          icon: Icons.location_on_outlined,
          label: 'Address',
          value: _valueOr(location.address, 'Address not provided.'),
          accentColor: accentColor,
          iconBackground: iconBackground,
        ),
      ],
    );
  }

  Widget _photoPlaceholder(String message) {
    final isBusiness = location.type == MapLocationType.business;

    return ColoredBox(
      color: const Color(0xFFEDF2F7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBusiness
                    ? Icons.storefront_outlined
                    : Icons.account_balance_outlined,
                size: 40,
                color: isBusiness
                    ? const Color(0xFF467A45)
                    : const Color(0xFF8055A6),
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

  Widget _locationPhoto(BuildContext context) {
    final isBusiness = location.type == MapLocationType.business;
    final url = location.photoUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);

    final validUrl =
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;

    final missingPhotoMessage = isBusiness
        ? 'No business photo yet'
        : 'No landmark photo yet';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: !validUrl
            ? _photoPlaceholder(
                url.isEmpty ? missingPhotoMessage : 'Photo unavailable',
              )
            : Tooltip(
                message: 'View full photo',
                child: Semantics(
                  button: true,
                  label: 'View full photo of ${location.title}',
                  child: GestureDetector(
                    onTap: () {
                      _openLocationPhoto(context, url);
                    },
                    child: Image.network(
                      url,
                      key: ValueKey(url),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: 'Photo of ${location.title}',
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }

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

  Widget _businessDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18233F),
          ),
        ),
        const SizedBox(height: 12),
        _businessCategoryCard(),
        const SizedBox(height: 22),
        _section(
          'About this business',
          _valueOr(location.description, 'Description not provided yet.'),
          titleColor: const Color(0xFF467A45),
        ),
        _businessInformationCard(),
        const SizedBox(height: 22),
        promotionSection ??
            _section(
              'Promotions',
              'No current promotions are available.',
              titleColor: const Color(0xFF467A45),
            ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child:
              voucherSection ??
              _section(
                'Business vouchers',
                'Voucher availability is not connected for this business.',
                titleColor: const Color(0xFF467A45),
              ),
        ),
      ],
    );
  }

  Widget _landmarkDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18233F),
          ),
        ),
        const SizedBox(height: 12),
        _landmarkCategoryCard(),
        const SizedBox(height: 22),
        _section(
          'About this landmark',
          _valueOr(location.description, 'Description not provided yet.'),
          titleColor: const Color(0xFF8055A6),
        ),
        _landmarkInformationCard(),
        const SizedBox(height: 22),
      ],
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

                  _locationPhoto(context),
                  const SizedBox(height: 18),

                  if (onNavigate != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('navigate-location-button'),
                        onPressed: onNavigate,
                        style: FilledButton.styleFrom(
                          backgroundColor: isBusiness
                              ? const Color(0xFF467A45)
                              : const Color(0xFF8055A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.directions_walk),
                        label: const Text(
                          'Navigate with Google Maps',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 18),
                  if (isBusiness) _businessDetails() else _landmarkDetails(),
                  _section(
                    'Ratings and reviews',
                    'The shared review module is not connected yet.',
                    titleColor: isBusiness
                        ? const Color(0xFF467A45)
                        : const Color(0xFF8055A6),
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
