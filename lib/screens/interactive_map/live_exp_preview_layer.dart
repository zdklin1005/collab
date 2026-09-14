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

import 'live_exp_collection_check.dart';
import 'reward_collection_check.dart';
import 'out_of_range_dialog.dart';
import 'reward_preview_dialog.dart';

typedef LiveExpAvailabilityCheck =
    Future<LiveRewardCollectionCheck> Function(
      RewardMarker selectedReward,
      List<RewardMarker> Function(DateTime instant) currentRewardsAt,
      bool Function() sourceReady,
    );

class LiveExpPreviewLayer extends StatefulWidget {
  const LiveExpPreviewLayer({
    super.key,
    required this.places,
    required this.businesses,
    required this.onCheckExpAvailability,
    required this.collectionRadiusMeters,
    required this.onFocusReward,
  });

  final List<MapLocation> places;
  final List<Business> businesses;
  final LiveExpAvailabilityCheck onCheckExpAvailability;
  final double collectionRadiusMeters;
  final ValueChanged<RewardMarker> onFocusReward;

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
    final now = DateTime.now();

    if (_dialogOpen ||
        ModalRoute.of(context)?.isCurrent != true ||
        !reward.canDisplayAt(now) ||
        !_rewardsAt(now).any((current) => current.id == reward.id)) {
      return;
    }

    _dialogOpen = true;

    try {
      final check = await widget.onCheckExpAvailability(
        reward,
        _rewardsAt,
        () => mounted && !_loadingVouchers && !_voucherLoadFailed,
      );

      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }

      var locationName = reward.locationType == MapLocationType.business
          ? 'this business'
          : 'this landmark';

      for (final place in widget.places) {
        if (place.type == reward.locationType &&
            place.sourceDocumentId == reward.locationId) {
          locationName = place.title;
          break;
        }
      }

      final distance = check.localCheck?.distanceMeters;
      var focusRequested = false;

      final shouldFocus = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          if (check.status == LiveRewardCollectionStatus.localCheckFailed &&
              check.localCheck?.status ==
                  RewardCollectionCheckStatus.outOfRange &&
              distance != null) {
            return OutOfRangeDialog(
              distanceMeters: distance,
              radiusMeters: widget.collectionRadiusMeters,
              isDemo: false,
              onGetCloser: () {
                if (focusRequested) return;

                focusRequested = true;
                Navigator.of(dialogContext).pop(true);
              },
            );
          }

          // Do not describe a blocked or unavailable EXP reward as ready.
          if (!check.canAttemptClaim) {
            return AlertDialog(
              title: const Text('Cannot collect yet'),
              content: SingleChildScrollView(
                child: Text(_expAvailabilityMessage(check)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Back to map'),
                ),
              ],
            );
          }

          return RewardPreviewDialog(
            reward: reward,
            locationName: locationName,
            isDemo: false,
            noteOverride: reward.type == RewardType.exp
                ? 'Your current location passed the local range checks.\n'
                      'Collection is not enabled yet. No EXP has been awarded.'
                : 'Your current location passed the local range checks.\n'
                      'Voucher claiming is not enabled yet. No voucher has been issued.',
            // Keep Collect disabled until real claims are connected.
            onCollect: null,
          );
        },
      );

      if (shouldFocus == true &&
          mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        widget.onFocusReward(reward);
      }
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

  String _expAvailabilityMessage(LiveRewardCollectionCheck check) {
    switch (check.status) {
      case LiveRewardCollectionStatus.ready:
        return 'Your current GPS and this reward passed the local checks. '
            'No EXP has been awarded yet.';

      case LiveRewardCollectionStatus.simulationBlocked:
        return 'Movement testing is enabled. Live reward collection is blocked.';

      case LiveRewardCollectionStatus.sourceUnavailable:
        return 'Reward data is not ready. Wait for loading to finish '
            'or retry the failed connection.';

      case LiveRewardCollectionStatus.rewardChanged:
        return 'This reward has changed or is no longer available. '
            'Close this preview and select a current marker.';

      case LiveRewardCollectionStatus.localCheckFailed:
        return switch (check.localCheck?.status) {
          RewardCollectionCheckStatus.appInactive =>
            'Return to Discover and try again.',
          RewardCollectionCheckStatus.rewardUnavailable =>
            'This reward is no longer available.',
          RewardCollectionCheckStatus.locationAccessRequired =>
            'Enable location permission and location services.',
          RewardCollectionCheckStatus.locationUnavailable =>
            'Wait for a fresh GPS position, then try again.',
          RewardCollectionCheckStatus.locationUnreliable =>
            'Your GPS reading is stale or not accurate enough. '
                'Try again somewhere with a clearer GPS signal.',
          RewardCollectionCheckStatus.invalidCoordinates =>
            'The location coordinates are invalid.',
          RewardCollectionCheckStatus.outOfRange =>
            'You are outside the collection radius. '
                'Current distance: '
                '${check.localCheck!.distanceMeters!.toStringAsFixed(0)} m.',
          _ => 'Could not confirm collection eligibility. Please try again.',
        };
    }
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
