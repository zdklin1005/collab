import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_location.dart';
import '../../models/reward_marker.dart';
import '../../services/daily_reward_generator.dart';
import '../../models/localquest_models.dart';
import '../../services/live_reward_preview_generator.dart';
import '../../services/map_repository.dart';

class LiveExpPreviewLayer extends StatefulWidget {
  const LiveExpPreviewLayer({
    super.key,
    required this.places,
    required this.businesses,
  });

  final List<MapLocation> places;
  final List<Business> businesses;

  @override
  State<LiveExpPreviewLayer> createState() => _LiveExpPreviewLayerState();
}

class _LiveExpPreviewLayerState extends State<LiveExpPreviewLayer>
    with WidgetsBindingObserver {
  Timer? _dayTimer;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayRefresh();
    _startVoucherWatch();
  }

  void _scheduleDayRefresh() {
    _dayTimer?.cancel();

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }

    final now = DateTime.now().toUtc();
    var nextRefresh = DailyRewardGenerator.dayStartUtc(
      now,
    ).add(const Duration(days: 1));

    for (final campaign in _campaigns) {
      for (final boundary in [campaign.startDate, campaign.endDate]) {
        if (boundary.isAfter(now) && boundary.isBefore(nextRefresh)) {
          nextRefresh = boundary;
        }
      }
    }

    _dayTimer = Timer(
      nextRefresh.difference(now) + const Duration(milliseconds: 100),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleDayRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleDayRefresh();
    } else {
      _dayTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _voucherRequestId++;
    final subscription = _voucherSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _showPreview(RewardMarker reward) async {
    if (_dialogOpen ||
        ModalRoute.of(context)?.isCurrent != true ||
        !reward.canDisplayAt(DateTime.now()) ||
        !_rewardsAt(DateTime.now()).any((current) => current.id == reward.id)) {
      return;
    }

    _dialogOpen = true;

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            reward.type == RewardType.voucher
                ? 'Voucher preview'
                : 'EXP preview',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Preview only. Collection and account rewards '
                  'are not connected yet.',
                ),
                if (reward.voucherId != null)
                  Text('Voucher offer ID: ${reward.voucherId}'),
                const SizedBox(height: 16),
                Text('Location type: ${reward.locationType.name}'),
                Text('Location ID: ${reward.locationId}'),
                Text('Checkpoint: ${reward.checkpointId}'),
                const SizedBox(height: 8),
                const Text('Daily availability follows Malaysia time.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  StreamSubscription<List<Campaign>>? _voucherSubscription;
  List<Campaign> _campaigns = const [];
  bool _loadingVouchers = true;
  bool _voucherLoadFailed = false;
  int _voucherRequestId = 0;

  void _startVoucherWatch() {
    final requestId = ++_voucherRequestId;
    final previous = _voucherSubscription;
    if (previous != null) {
      unawaited(previous.cancel());
    }

    _campaigns = const [];
    _loadingVouchers = true;
    _voucherLoadFailed = false;

    _voucherSubscription = MapRepository().watchActiveVoucherCampaigns().listen(
      (campaigns) {
        if (!mounted || requestId != _voucherRequestId) return;

        setState(() {
          _campaigns = campaigns;
          _loadingVouchers = false;
          _voucherLoadFailed = false;
        });
        _scheduleDayRefresh();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || requestId != _voucherRequestId) return;

        setState(() {
          _campaigns = const [];
          _loadingVouchers = false;
          _voucherLoadFailed = true;
        });
        _scheduleDayRefresh();
      },
    );
  }

  List<RewardMarker> _rewardsAt(DateTime instant) {
    return generateLiveRewardPreviews(
      places: widget.places,
      businesses: widget.businesses,
      campaigns: _loadingVouchers || _voucherLoadFailed
          ? const <Campaign>[]
          : _campaigns,
      instant: instant,
    );
  }

  Widget _buildRewardMarkers(BuildContext context) {
    final now = DateTime.now();
    final rewards = _rewardsAt(now);

    return MarkerLayer(
      markers: [
        for (final reward in rewards)
          if (reward.canDisplayAt(now))
            Marker(
              key: ValueKey('live-exp-preview:${reward.id}'),
              point: LatLng(reward.latitude, reward.longitude),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              rotate: true,
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Tooltip(
                    message: '${reward.title} · Preview only',
                    child: Material(
                      color: reward.type == RewardType.voucher
                          ? const Color(0xFF3267D8)
                          : const Color(0xFFE99A00),
                      elevation: 3,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => unawaited(_showPreview(reward)),
                        child: Center(
                          child: Icon(
                            reward.type == RewardType.voucher
                                ? Icons.confirmation_number_outlined
                                : Icons.star_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildRewardMarkers(context),
        if (_loadingVouchers || _voucherLoadFailed)
          Positioned(
            left: 16,
            right: 84,
            bottom: 210,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _loadingVouchers
                    ? const Text('Loading voucher previews…')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Could not load voucher previews.'),
                          TextButton(
                            onPressed: () => setState(_startVoucherWatch),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
