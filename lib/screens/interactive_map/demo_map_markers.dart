import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/mock_map_data.dart';
import '../../models/map_location.dart';
import '../../models/reward_marker.dart';

import '../../services/daily_reward_generator.dart';

class DemoMapMarkers extends StatefulWidget {
  const DemoMapMarkers({
    super.key,
    this.now,
  });

  // Tests can supply a clock. Normal app usage uses real time.
  final DateTime Function()? now;

  @override
  State<DemoMapMarkers> createState() => _DemoMapMarkersState();
}

class _DemoMapMarkersState extends State<DemoMapMarkers>
    with WidgetsBindingObserver {
  final _locations = MockMapData.createLocations();

  List<RewardMarker> _rewards = [];
  DateTime? _generatedDay;
  Timer? _refreshTimer;

  DateTime _nowUtc() {
    return (widget.now?.call() ?? DateTime.now()).toUtc();
  }

  //Refresh the daily rewards if the day has changed since the last generation.
  void _refreshDailyRewards() {
    final now = _nowUtc();
    final day = DailyRewardGenerator.dayStartUtc(now);

    if (_generatedDay == day) return;

    final generated = MockMapData.createDailyRewards(now);

    _rewards = generated;
    _generatedDay = day;

    debugPrint(
      'Demo daily rewards ready: '
      '${generated.length} markers; day starts ${day.toIso8601String()}',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _refreshDailyRewards();

    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;

      setState(() {
        // Switch to the new daily batch after Malaysian midnight.
        _refreshDailyRewards();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;

      setState(() {
        // Also handles returning after midnight.
        _refreshDailyRewards();
      });

      _startRefreshTimer();
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showRecord(String title, String details) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Demo: $title'),
        content: Text(
          '$details\n\n'
          'Fictional test data. No collection or voucher claim is available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Marker _marker({
    required String id,
    required double latitude,
    required double longitude,
    required String title,
    required String details,
    required IconData icon,
    required Color color,
  }) {
    return Marker(
      key: ValueKey(id),
      point: LatLng(latitude, longitude),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      rotate: true,
      child: Tooltip(
        message: 'Demo: $title',
        child: Material(
          color: color,
          elevation: 3,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _showRecord(title, details),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = _nowUtc();

    return MarkerLayer(
      markers: [
        for (final location in _locations.where((item) => item.canDisplay))
          _marker(
            id: location.id,
            latitude: location.latitude,
            longitude: location.longitude,
            title: location.title,
            details: 'Type: ${location.type.name}\n'
                'Record: ${location.id}\n'
                'Category: ${location.category}',
            icon: location.type == MapLocationType.business
                ? Icons.storefront_outlined
                : Icons.account_balance_outlined,
            color: location.type == MapLocationType.business
                ? const Color(0xFF467A45)
                : const Color(0xFF8055A6),
          ),

        for (final reward in _rewards.where((item) => item.canDisplayAt(now)))
          _marker(
            id: reward.id,
            latitude: reward.latitude,
            longitude: reward.longitude,
            title: reward.title,
            details: 'Type: ${reward.type.name}\n'
                'Record: ${reward.id}\n'
                'Checkpoint: ${reward.checkpointId}\n'
                'Business: ${reward.businessId}\n'
                '${reward.type == RewardType.exp ? 'EXP: ${reward.expAmount}' : 'Voucher: ${reward.voucherId}'}',
            icon: reward.type == RewardType.exp
                ? Icons.star_rounded
                : Icons.confirmation_number_outlined,
            color: reward.type == RewardType.exp
                ? const Color(0xFFD88A00)
                : const Color(0xFF3267D8),
          ),
      ],
    );
  }
}