import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/localquest_models.dart';

class InteractiveMapScreen extends StatelessWidget {
  const InteractiveMapScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  // Temporary starting position: central Kuala Lumpur.
  // This is not the phone's current location.
  static const LatLng initialPosition = LatLng(3.1390, 101.6869);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialPosition,
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.localquest.app',
            ),
          ],
        ),

        // Keep attribution visible above the floating navigation.
        const Positioned(
          left: 12,
          bottom: 110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}