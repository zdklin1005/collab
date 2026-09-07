import 'package:flutter/material.dart';

import '../../core/localquest_theme.dart';

class MapActionButtons extends StatelessWidget {
  const MapActionButtons({
    super.key,
    required this.onCurrentLocation,
    this.onDemoArea,
    this.onMapStyle,
  });

  final VoidCallback onCurrentLocation;
  final VoidCallback? onDemoArea;
  final VoidCallback? onMapStyle;

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapActionButton(
          icon: Icons.my_location,
          tooltip: 'Current location',
          onPressed: onCurrentLocation,
        ),

        const SizedBox(height: 12),
        _MapActionButton(
          icon: Icons.layers_outlined,
          tooltip: 'Map layers',
          onPressed: onMapStyle ??
              () => _showMessage(context, 'Map-style selection is unavailable.'),
        ),

        const SizedBox(height: 12),
        _MapActionButton(
          icon: Icons.search,
          tooltip: 'Search businesses',
          primary: true,
          onPressed: () => _showMessage(
            context,
            'Business search is not available yet.',
          ),
        ),

        if (onDemoArea != null) ...[
          const SizedBox(height: 12),
          _MapActionButton(
            icon: Icons.science_outlined,
            tooltip: 'Demo area — fictional markers',
            onPressed: onDemoArea!,
          ),
        ],
      ],
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? LqColors.primary : Colors.white,
      elevation: 4,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 52,
        height: 52,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 26,
            color: primary ? Colors.white : LqColors.ink,
          ),
        ),
      ),
    );
  }
}