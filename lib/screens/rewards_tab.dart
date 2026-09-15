import 'package:flutter/material.dart';

import '../models/localquest_models.dart';
import '../services/device_location_service.dart';
import 'mission_list_screen.dart';

/// Content for the tourist "Rewards" tab. Fetches the device's current
/// position once (via [DeviceLocationService]) and hands it to
/// [MissionListView].
///
/// Drop this in as the second entry of `TouristHome`'s `pages` list in
/// tourist_screens.dart, in place of the "Rewards" `_ModulePlaceholder`.
class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key, required this.user});
  final AppUser user;

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  double? _lat;
  double? _lng;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _error = null);
    try {
      final position = await DeviceLocationService.instance
          .getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 40,
                color: Colors.black38,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadLocation,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_lat == null || _lng == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MissionListView(
      uid: widget.user.id,
      currentLat: _lat!,
      currentLng: _lng!,
    );
  }
}
