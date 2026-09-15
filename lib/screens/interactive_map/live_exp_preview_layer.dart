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

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/map_exp_history_repository.dart';

import '../../services/map_exp_visibility.dart';

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
    required this.userId,
  });

  final List<MapLocation> places;
  final List<Business> businesses;
  final LiveExpAvailabilityCheck onCheckExpAvailability;
  final double collectionRadiusMeters;
  final ValueChanged<RewardMarker> onFocusReward;
  final String userId;

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
    _startHistoryWatch();
  }

  @override
  void didUpdateWidget(covariant LiveExpPreviewLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _startHistoryWatch();
    }
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

    final cooldowns = _cooldownHistory?.data;

    if (cooldowns != null) {
      for (final cooldown in cooldowns.values) {
        final boundary = cooldown.nextEligibleAt;

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
    _historyRequestId++;
    _cancelHistoryWatch();
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
        !_historyReady ||
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
        () =>
            mounted &&
            _historyReady &&
            !_loadingVouchers &&
            !_voucherLoadFailed,
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
    final claims = _claimHistory;
    final cooldowns = _cooldownHistory;

    if (!_historyReady || claims == null || cooldowns == null) {
      return const <RewardMarker>[];
    }

    final generated = generateLiveRewardPreviews(
      places: widget.places,
      businesses: widget.businesses,
      campaigns: _loadingVouchers || _voucherLoadFailed
          ? const <Campaign>[]
          : _campaigns,
      instant: instant,
    );

    return filterMapExpHistory(
      rewards: generated,
      claimedRewardIds: claims.data,
      cooldowns: cooldowns.data,
      now: instant,
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

  StreamSubscription<MapHistorySnapshot<Set<String>>>?
  _claimHistorySubscription;

  StreamSubscription<MapHistorySnapshot<Map<String, MapCheckpointCooldown>>>?
  _cooldownHistorySubscription;

  MapHistorySnapshot<Set<String>>? _claimHistory;
  MapHistorySnapshot<Map<String, MapCheckpointCooldown>>? _cooldownHistory;

  Timer? _historyTimeout;
  int _historyRequestId = 0;
  bool _historyFailed = false;

  bool get _historyReady =>
      !_historyFailed &&
      _claimHistory?.serverConfirmed == true &&
      _cooldownHistory?.serverConfirmed == true;

  void _cancelHistoryWatch() {
    _historyTimeout?.cancel();

    final claims = _claimHistorySubscription;
    final cooldowns = _cooldownHistorySubscription;

    _claimHistorySubscription = null;
    _cooldownHistorySubscription = null;

    if (claims != null) {
      unawaited(claims.cancel());
    }
    if (cooldowns != null) {
      unawaited(cooldowns.cancel());
    }
  }

  void _startHistoryWatch() {
    final requestId = ++_historyRequestId;
    _cancelHistoryWatch();

    _claimHistory = null;
    _cooldownHistory = null;
    _historyFailed = false;

    void fail(Object error, StackTrace stackTrace) {
      if (!mounted || requestId != _historyRequestId) return;

      _historyTimeout?.cancel();
      setState(() {
        _historyFailed = true;
      });
    }

    void receivedHistory() {
      // Only both server-confirmed streams can clear a previous failure.
      if (_claimHistory?.serverConfirmed == true &&
          _cooldownHistory?.serverConfirmed == true) {
        _historyFailed = false;
        _historyTimeout?.cancel();
      }

      _scheduleDayRefresh();
    }

    _historyTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted || requestId != _historyRequestId || _historyReady) {
        return;
      }

      setState(() {
        _historyFailed = true;
      });
    });

    try {
      final repository = MapExpHistoryRepository(
        firestore: FirebaseFirestore.instance,
      );

      _claimHistorySubscription = repository
          .watchClaimedRewardIds(widget.userId)
          .listen((snapshot) {
            if (!mounted || requestId != _historyRequestId) return;

            setState(() {
              _claimHistory = snapshot;
              receivedHistory();
            });
          }, onError: fail);

      _cooldownHistorySubscription = repository
          .watchCheckpointCooldowns(widget.userId)
          .listen((snapshot) {
            if (!mounted || requestId != _historyRequestId) return;

            setState(() {
              _cooldownHistory = snapshot;
              receivedHistory();
            });
          }, onError: fail);
    } catch (error, stackTrace) {
      fail(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_historyReady) {
      return _buildHistoryStatus();
    }
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

  Widget _buildHistoryStatus() {
    return Stack(
      children: [
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _historyFailed
                        ? 'Could not confirm your reward history. '
                              'Check your connection and retry.'
                        : 'Checking your reward history…',
                  ),
                  if (_historyFailed)
                    TextButton(
                      onPressed: () => setState(_startHistoryWatch),
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
