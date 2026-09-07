import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_style.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({
    super.key,
    required this.style,
  });

  final MapStyle style;

  Future<void> _open(BuildContext context, String address) async {
    try {
      final opened = await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      );

      if (opened) return;
    } catch (_) {
      // Show a friendly message without printing request details.
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the attribution page.'),
      ),
    );
  }

  Widget _credit(
    BuildContext context,
    String label,
    String address,
  ) {
    return InkWell(
      onTap: () => _open(context, address),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final satellite = style == MapStyle.satellite;

    return Align(
      alignment: Alignment.bottomLeft,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (satellite)
                InkWell(
                  onTap: () => _open(context, 'https://www.maptiler.com/'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SvgPicture.asset(
                      'assets/maptiler-logo.svg',
                      width: 88,
                      semanticsLabel: 'MapTiler',
                    ),
                  ),
                ),
              if (satellite)
                _credit(
                  context,
                  '© MapTiler',
                  'https://www.maptiler.com/copyright/',
                ),
              _credit(
                context,
                '© OpenStreetMap contributors',
                'https://www.openstreetmap.org/copyright',
              ),
            ],
          ),
        ),
      ),
    );
  }
}