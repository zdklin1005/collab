import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_test_config.dart';

import '../../data/mock_map_data.dart';

import '../../models/map_location.dart';
import '../../models/localquest_models.dart';
import '../../models/reward_marker.dart';

import '../../services/map_category_filter.dart';
import '../../services/reward_proximity.dart';
import '../../services/demo_map_claim_store.dart';
import '../../services/demo_map_claim_persistence.dart';
import '../../services/nearby_business_detector.dart';
import '../../services/nearby_business_prompt_tracker.dart';
import '../../services/daily_reward_generator.dart';
import '../../services/demo_business_voucher_claim_store.dart';
import '../../services/demo_business_voucher_claim_persistence.dart';

import '../../services/map_repository.dart';

import 'map_action_buttons.dart';
import 'map_location_permission.dart';
import 'map_progress_card.dart';
import 'map_tiles_with_status.dart';
import 'compass_user_marker.dart';
import 'location_quality.dart';

import 'demo_map_markers.dart';
import 'map_style.dart';
import 'map_attribution.dart';
import 'map_style_preferences.dart';
import 'map_search_delegate.dart';
import 'map_location_details.dart';

import 'reward_preview_dialog.dart';
import 'out_of_range_dialog.dart';
import 'reward_collection_check.dart';
import 'reward_success_screen.dart';

import 'nearby_business_dialog.dart';
import 'business_voucher_claim_check.dart';
import 'business_voucher_section.dart';

import '../../core/map_movement_test_config.dart';
import '../../services/map_test_movement_controller.dart';
import 'map_test_movement_controls.dart';

import 'live_exp_preview_layer.dart';
import 'live_exp_collection_check.dart';
import 'live_business_voucher_section.dart';
import 'live_business_promotion_section.dart';
import 'live_business_voucher_details_dialog.dart';
import '../../services/live_business_voucher_claim_service.dart';
import 'live_business_voucher_collection_check.dart';

class InteractiveMapScreen extends StatefulWidget {
  const InteractiveMapScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen>
    with WidgetsBindingObserver {
  MapTestMovementController? _testMovement;
  bool _testMovementRunning = false;

  LatLng? get _displayPoint {
    if (MapMovementTestConfig.enabled) {
      if (!_testMovementRunning || !_foreground || !_locationAllowed) {
        return null;
      }

      return _testMovement?.point;
    }

    final position = _position;
    return position == null
        ? null
        : LatLng(position.latitude, position.longitude);
  }

  // Used only for nearby-business discovery, never for reward claims.
  LatLng? get _discoveryPoint {
    if (!mounted || !_foreground || !_locationAllowed) return null;

    if (MapMovementTestConfig.enabled) {
      return _displayPoint;
    }

    final position = _position;
    if (_locationError != null || position == null) return null;

    final quality = assessLocationQuality(
      accuracy: position.accuracy,
      recordedAt: position.timestamp,
      now: DateTime.now(),
    );

    if (quality != LocationQuality.recent ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      return null;
    }

    return LatLng(position.latitude, position.longitude);
  }

  final LiveBusinessVoucherClaimService _liveBusinessVoucherClaimService =
      LiveBusinessVoucherClaimService();

  static const double _liveBusinessVoucherClaimRadiusMeters = 50;

  void _startTestLocation() {
    final start = MapMovementTestConfig.start;

    if (!mounted ||
        !_foreground ||
        !_locationAllowed ||
        start == null ||
        _testMovementRunning) {
      return;
    }

    _stopLiveLocation();

    _testMovement ??= MapTestMovementController(
      start: start,
      stepMeters: MapMovementTestConfig.stepMeters,
    );

    final requestId = _requestId;

    setState(() {
      _testMovementRunning = true;
      _position = null;
      _locating = false;
      _locationError = null;
      _updateNearbyBusinesses();
    });

    // Allows reminder spacing to expire while the test marker is stationary.
    // It does not request GPS or manufacture GPS accuracy readings.
    _qualityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isCurrentRequest(requestId) || !_testMovementRunning) return;

      setState(() {
        _updateNearbyBusinesses();
      });
    });

    _centreOnFirstPosition();
  }

  void _changeTestPosition({TestMoveDirection? direction}) {
    final controller = _testMovement;

    if (!MapMovementTestConfig.enabled ||
        !mounted ||
        !_foreground ||
        !_locationAllowed ||
        !_testMovementRunning ||
        !_mapReady ||
        controller == null ||
        _searchOpen ||
        _filterSheetOpen ||
        _locationDetailsOpen ||
        _nearbyBusinessDialogOpen ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    try {
      setState(() {
        if (direction == null) {
          controller.reset();
        } else {
          controller.move(direction);
        }

        _updateNearbyBusinesses();
      });

      _recenterWhenReady = true;
      _centreOnFirstPosition();
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This movement would leave the supported test area.'),
        ),
      );
    }
  }

  static const _initialPosition = LatLng(3.1390, 101.6869);

  final MapController _mapController = MapController();

  StreamSubscription<List<Business>>? _businessSubscription;
  List<MapLocation> _liveLocations = const [];
  List<Business> _liveBusinesses = const [];
  bool _loadingBusinesses = true;
  bool _businessLoadFailed = false;
  int _businessRequestId = 0;

  StreamSubscription<List<MapLocation>>? _landmarkSubscription;
  List<MapLocation> _liveLandmarks = const [];
  bool _loadingLandmarks = true;
  bool _landmarkLoadFailed = false;
  int _landmarkRequestId = 0;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _firstFixTimer;
  Timer? _qualityTimer;
  Future<void> _pendingStop = Future<void>.value();
  MapStyle _mapStyle = MapStyle.standard;

  StreamSubscription<List<Campaign>>? _businessCampaignSubscription;
  List<Campaign> _liveBusinessCampaigns = const [];
  bool _loadingBusinessCampaigns = true;
  bool _businessCampaignLoadFailed = false;
  int _businessCampaignRequestId = 0;

  Position? _position;
  String? _selectedBusinessCategory;
  String? _selectedLandmarkCategory;
  bool _filterSheetOpen = false;
  bool _restoringMapStyle = true;
  bool _savingMapStyle = false;
  bool _searchOpen = false;
  bool _locationAllowed = false;
  bool _locating = false;
  bool _mapReady = false;
  bool _centredOnce = false;
  bool _recenterWhenReady = false;
  bool _foreground = true;
  bool _locationDetailsOpen = false;

  // Temporary demo value, not the final collection policy.
  static const double _demoCollectionRadiusMeters = 50;

  // Temporary business discovery radius.
  static const double _demoBusinessDiscoveryRadiusMeters = 100;

  List<NearbyBusiness> _nearbyBusinesses = const [];
  String? _lastNearbyDetectionKey;

  static final _nearbyPromptTracker = NearbyBusinessPromptTracker();

  // Courtesy interval between different businesses' reminders.
  // This is not a reward or voucher cooldown.
  static DateTime? _nextNearbyPromptAt;

  bool _nearbyPromptScheduled = false;
  bool _nearbyBusinessDialogOpen = false;

  // Shared by recreated map screens during this app session.
  // Claims remain separated by tourist ID.
  // Hot restart or a full app restart clears this in-memory data.
  // Shared across recreated Discover screens, separated by tourist ID.
  static DemoMapClaimStore _demoClaims = DemoMapClaimStore();
  static final _claimPersistence = DemoMapClaimPersistence();

  static DemoBusinessVoucherClaimStore _businessVoucherClaims =
      DemoBusinessVoucherClaimStore();

  static final _businessVoucherPersistence =
      DemoBusinessVoucherClaimPersistence();

  static bool _businessVoucherClaimInProgress = false;

  static Future<void> _pendingBusinessVoucherClaim = Future<void>.value();

  static Future<void>? _claimsLoadFuture;
  static Future<void> _pendingClaimSave = Future<void>.value();
  static bool _claimSaveInProgress = false;

  bool _restoringClaims = true;
  bool _savingClaim = false;
  String? _claimStorageError;

  bool _rewardDistanceDialogOpen = false;

  String? _locationError;
  int _requestId = 0;

  bool _liveBusinessVoucherDetailsOpen = false;

  // Temporary claim radius, separate from business discovery.
  static const double _demoBusinessVoucherClaimRadiusMeters = 50;

  @override
  void initState() {
    super.initState();
    if (!MapTestConfig.enabled) {
      _startLiveBusinesses();
      _startLiveLandmarks();
      _startLiveBusinessCampaigns();
    }
    WidgetsBinding.instance.addObserver(this);

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;

    unawaited(_restoreMapStyle());
    unawaited(_restoreDemoClaims());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    if (!_foreground) {
      _stopLiveLocation();

      setState(() {
        _position = null;
        _locationError = null;
      });
    }

    // On resume, MapLocationPermission rechecks access and calls
    // _onAccessChanged. Do not restart using an old permission result.
  }

  bool _isCurrentRequest(int id) {
    return mounted && _foreground && _locationAllowed && id == _requestId;
  }

  void _onAccessChanged(bool allowed) {
    if (!mounted) return;

    if (!allowed) {
      _stopLiveLocation();
    }

    setState(() {
      _locationAllowed = allowed;

      if (!allowed) {
        _position = null;
        _locationError = null;
        _centredOnce = false;
      }
    });

    if (allowed && _foreground) {
      _readPosition();
    }
  }

  Future<void> _selectMapStyle() async {
    if (_restoringMapStyle || _savingMapStyle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while the map preference is updated.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<MapStyle>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Map style',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                for (final style in MapStyle.values)
                  ListTile(
                    enabled:
                        style == MapStyle.standard ||
                        MapStyleConfig.satelliteAvailable,
                    leading: Icon(
                      style == MapStyle.standard
                          ? Icons.map_outlined
                          : Icons.satellite_alt,
                    ),
                    title: Text(MapStyleConfig.label(style)),
                    subtitle: Text(
                      style == MapStyle.standard
                          ? 'OpenStreetMap street map'
                          : MapStyleConfig.satelliteAvailable
                          ? 'MapTiler imagery with road and place labels'
                          : 'Satellite key missing. Restart with your '
                                'private configuration.',
                    ),
                    trailing: _mapStyle == style
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(style),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _mapStyle) return;

    if (selected == MapStyle.satellite && !MapStyleConfig.satelliteAvailable) {
      return;
    }

    setState(() {
      _mapStyle = selected;
      _savingMapStyle = true;
    });

    try {
      await MapStylePreferences.save(selected);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Map style changed, but the preference could not be saved.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingMapStyle = false;
        });
      }
    }
  }

  Future<void> _restoreMapStyle() async {
    try {
      final savedStyle = await MapStylePreferences.load(
        satelliteAvailable: MapStyleConfig.satelliteAvailable,
      );

      if (!mounted) return;

      setState(() {
        _mapStyle = savedStyle;
      });
    } catch (_) {
      // Keep the default Standard map usable if storage fails.
      debugPrint('Could not restore the map-style preference.');
    } finally {
      if (mounted) {
        setState(() {
          _restoringMapStyle = false;
        });
      }
    }
  }

  Future<void> _openMapSearch() async {
    if (!_mapReady || _searchOpen) return;

    final demoMode = MapTestConfig.enabled;
    final businessesReady = !_loadingBusinesses && !_businessLoadFailed;
    final landmarksReady = !_loadingLandmarks && !_landmarkLoadFailed;

    if (!demoMode && !businessesReady && !landmarksReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Places are loading or unavailable. '
            'Check the map status and retry if needed.',
          ),
        ),
      );
      return;
    }

    final locations = filterMapLocations(
      demoMode
          ? MockMapData.createLocations()
          : <MapLocation>[
              if (businessesReady) ..._liveLocations,
              if (landmarksReady) ..._liveLandmarks,
            ],
      _selectedBusinessCategory,
      selectedLandmarkCategory: _selectedLandmarkCategory,
    );

    final informationText = demoMode
        ? 'Demo places only. Business and landmark category filters apply here. '
        : [
            'Search loaded businesses and landmarks.',
            if (!businessesReady)
              'Businesses are currently unavailable or still loading.',
            if (!landmarksReady)
              'Landmarks are currently unavailable or still loading.',
            'Business and landmark category filters apply independently.',
            'Reopen search to refresh the results.',
          ].join(' ');

    final touristId = widget.user.id;
    _searchOpen = true;

    try {
      final selected = await showSearch<MapLocation?>(
        context: context,
        delegate: MapSearchDelegate(
          locations: locations,
          informationText: informationText,
        ),
      );

      if (!mounted ||
          !_mapReady ||
          !_foreground ||
          widget.user.id != touristId ||
          selected == null) {
        return;
      }

      MapLocation destination = selected;

      if (!demoMode) {
        // Recheck the selected place against the latest data.
        // A failure in one collection must not block the other.
        final latestLocations = <MapLocation>[
          if (!_loadingBusinesses && !_businessLoadFailed) ..._liveLocations,
          if (!_loadingLandmarks && !_landmarkLoadFailed) ..._liveLandmarks,
        ];

        final matches = filterMapLocations(
          latestLocations,
          _selectedBusinessCategory,
          selectedLandmarkCategory: _selectedLandmarkCategory,
        ).where((location) => location.id == selected.id).toList();

        if (matches.length != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This place is no longer available. Please search again.',
              ),
            ),
          );
          return;
        }

        destination = matches.single;
      }

      if (!destination.canDisplay) return;

      _centredOnce = true;
      _recenterWhenReady = false;

      _mapController.move(
        LatLng(destination.latitude, destination.longitude),
        17,
      );

      await _showLocationDetails(destination);
    } finally {
      _searchOpen = false;
    }
  }

  Future<void> _selectBusinessCategory() async {
    if (_filterSheetOpen) return;

    final demoMode = MapTestConfig.enabled;
    final businessesReady =
        demoMode || (!_loadingBusinesses && !_businessLoadFailed);
    final landmarksReady =
        demoMode || (!_loadingLandmarks && !_landmarkLoadFailed);

    final businessCategories = availableBusinessCategories(
      demoMode
          ? MockMapData.createLocations()
          : businessesReady
          ? _liveLocations
          : const <MapLocation>[],
    );

    final landmarkCategories = availableLandmarkCategories(
      demoMode
          ? MockMapData.createLocations()
          : landmarksReady
          ? _liveLandmarks
          : const <MapLocation>[],
    );

    _filterSheetOpen = true;
    final touristId = widget.user.id;

    try {
      final selected = await showModalBottomSheet<(MapLocationType, String)>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          Widget categorySection({
            required MapLocationType type,
            required String heading,
            required String allLabel,
            required List<String> categories,
            required String? current,
            required bool ready,
          }) {
            final choices = <String>[
              ...categories,
              // Keep an existing selection visible if its records disappear.
              if (current != null && !categories.contains(current)) current,
            ];

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: Text(allLabel),
                  trailing: current == null
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop((type, '')),
                ),
                for (final category in choices)
                  ListTile(
                    leading: Icon(
                      type == MapLocationType.business
                          ? Icons.storefront_outlined
                          : Icons.account_balance_outlined,
                    ),
                    title: Text(category),
                    trailing: current == category
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () =>
                        Navigator.of(sheetContext).pop((type, category)),
                  ),
                if (!ready || categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      !ready
                          ? 'These places are loading or unavailable. '
                                'You can still clear their filter.'
                          : 'No categories are currently available.',
                    ),
                  ),
              ],
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Filter places',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Each category filters its own markers and search '
                          'results. EXP and voucher markers stay visible.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  categorySection(
                    type: MapLocationType.business,
                    heading: 'Businesses',
                    allLabel: 'All businesses',
                    categories: businessCategories,
                    current: _selectedBusinessCategory,
                    ready: businessesReady,
                  ),
                  const Divider(),
                  categorySection(
                    type: MapLocationType.landmark,
                    heading: 'Landmarks',
                    allLabel: 'All landmarks',
                    categories: landmarkCategories,
                    current: _selectedLandmarkCategory,
                    ready: landmarksReady,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || widget.user.id != touristId || selected == null) {
        return;
      }

      setState(() {
        final category = selected.$2.isEmpty ? null : selected.$2;

        if (selected.$1 == MapLocationType.business) {
          _selectedBusinessCategory = category;
        } else {
          _selectedLandmarkCategory = category;
        }
      });
    } finally {
      _filterSheetOpen = false;
    }
  }

  void _startLiveLandmarks() {
    final requestId = ++_landmarkRequestId;
    final previous = _landmarkSubscription;

    if (previous != null) {
      unawaited(previous.cancel());
    }

    _liveLandmarks = const [];
    _loadingLandmarks = true;
    _landmarkLoadFailed = false;

    _landmarkSubscription = MapRepository().watchActiveLandmarks().listen(
      (landmarks) {
        if (!mounted || requestId != _landmarkRequestId) return;

        setState(() {
          _liveLandmarks = List<MapLocation>.unmodifiable(landmarks);
          _loadingLandmarks = false;
          _landmarkLoadFailed = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || requestId != _landmarkRequestId) return;

        setState(() {
          _liveLandmarks = const [];
          _loadingLandmarks = false;
          _landmarkLoadFailed = true;
        });

        debugPrint('Map: landmark loading failed: $error');
      },
    );
  }

  Future<void> _showLocationDetails(MapLocation location) async {
    if (!mounted || _locationDetailsOpen || !location.canDisplay) return;

    final businessSource = MapTestConfig.enabled
        ? MockMapData.businesses
        : _liveBusinesses;

    final matchingBusinesses =
        location.type == MapLocationType.business && location.businessId != null
        ? businessSource
              .where((business) => business.id == location.businessId)
              .toList()
        : <Business>[];

    final Business? business = matchingBusinesses.length == 1
        ? matchingBusinesses.single
        : null;

    // Keep one offer snapshot for this details visit.
    final offers = business == null
        ? <MapVoucherOffer>[]
        : _demoBusinessOffers(business);

    final checkedAt = DateTime.now();
    final touristId = widget.user.id;
    var voucherPreviewOpen = false;

    _locationDetailsOpen = true;

    Future<void> openVoucher(MapVoucherOffer selected) async {
      if (!mounted ||
          !_foreground ||
          !_locationDetailsOpen ||
          voucherPreviewOpen ||
          business == null) {
        return;
      }

      if (widget.user.id != touristId || touristId.trim().isEmpty) {
        _showDemoCollectionMessage(
          'The account changed. Close these details and open them again.',
        );
        return;
      }

      if (_restoringClaims || _claimStorageError != null) {
        _showDemoCollectionMessage(
          'Claim history is not ready. Close details and retry on Discover.',
        );
        return;
      }

      voucherPreviewOpen = true;
      var closing = false;

      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            void closePreview() {
              if (closing) return;
              closing = true;
              Navigator.of(dialogContext).pop();
            }

            return NearbyBusinessDialog(
              business: business,
              // Hidden for previews opened from business details.
              distanceMeters: 0,
              offers: offers,
              initialOffer: selected,
              onDismiss: closePreview,
              // Details are already underneath this dialog.
              onViewDetails: closePreview,
              onCheckEligibility: (voucherId) {
                return _checkSelectedBusinessVoucher(
                  touristId: touristId,
                  businessId: business.id,
                  voucherId: voucherId,
                  offers: offers,
                );
              },
              onClaim: (voucherId) {
                return _claimSelectedBusinessVoucher(
                  touristId: touristId,
                  businessId: business.id,
                  voucherId: voucherId,
                  offers: offers,
                  isPreviewOpen: () =>
                      voucherPreviewOpen && !closing && _locationDetailsOpen,
                );
              },
            );
          },
        );
      } finally {
        voucherPreviewOpen = false;
      }
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        backgroundColor: Colors.white,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: 0.85,
            child: MapLocationDetails(
              isDemo: MapTestConfig.enabled,
              location: location,
              onClose: () => Navigator.of(sheetContext).pop(),
              voucherSection: business == null
                  ? null
                  : MapTestConfig.enabled
                  ? BusinessVoucherSection(
                      business: business,
                      offers: offers,
                      checkedAt: checkedAt,
                      onSelected: (offer) {
                        unawaited(openVoucher(offer));
                      },
                    )
                  : _buildLiveBusinessVoucherSection(
                      business,
                      onSelected: (campaign) {
                        unawaited(
                          _showLiveBusinessVoucherDetails(
                            business: business,
                            campaign: campaign,
                            onRecorded: () {
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        );
                      },
                    ),
              promotionSection: business == null || MapTestConfig.enabled
                  ? null
                  : _buildLiveBusinessPromotionSection(business),
            ),
          );
        },
      );
    } finally {
      _locationDetailsOpen = false;
    }
  }

  // Starts one live subscription. Repeated calls do not create duplicates.
  Future<void> _readPosition() async {
    if (MapMovementTestConfig.enabled) {
      _startTestLocation();
      return;
    }
    if (!mounted ||
        !_foreground ||
        !_locationAllowed ||
        _locating ||
        _positionSubscription != null) {
      return;
    }

    final requestId = ++_requestId;

    setState(() {
      _locating = true;
      _position = null;
      _locationError = null;
    });

    try {
      // Let the previous subscription finish cancelling before restarting.
      await _pendingStop;
      if (!_isCurrentRequest(requestId)) return;

      final enabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      if (!_isCurrentRequest(requestId)) return;

      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!enabled || !granted) {
        _failLocation(
          'Location access is unavailable. Check your location settings.',
        );
        return;
      }

      // Only time out the initial fix. Standing still afterward should
      // not be treated as a failure.
      _firstFixTimer = Timer(const Duration(seconds: 20), () {
        if (_isCurrentRequest(requestId) && _position == null) {
          _failLocation(
            'Location is taking too long. Try again somewhere '
            'with a clearer view of the sky.',
          );
        }
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 3,
            ),
          ).listen(
            (position) {
              if (!_isCurrentRequest(requestId)) return;

              if (!position.latitude.isFinite ||
                  !position.longitude.isFinite ||
                  position.latitude.abs() > 90 ||
                  position.longitude.abs() > 180) {
                return;
              }

              _firstFixTimer?.cancel();
              _firstFixTimer = null;

              setState(() {
                _position = position;
                _locating = false;
                _locationError = null;
                _updateNearbyBusinesses();
              });

              _centreOnFirstPosition();
              debugPrint('Map location updated');
            },
            onError: (Object error) {
              if (!_isCurrentRequest(requestId)) return;

              debugPrint('Map location stream failed: $error');
              _failLocation(
                'Location updates stopped. Check your location settings '
                'and try again.',
              );
            },
            onDone: () {
              if (!_isCurrentRequest(requestId)) return;

              _failLocation('Location updates ended. Tap Retry location.');
            },
            cancelOnError: true,
          );

      // Refresh the age warning even when no new position arrives.
      // This timer does not request additional GPS readings.
      _qualityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_isCurrentRequest(requestId) && _position != null) {
          setState(() {
            _updateNearbyBusinesses();
          });
        }
      });

      debugPrint('Map location updates started');
    } catch (error) {
      if (!_isCurrentRequest(requestId)) return;

      debugPrint('Could not start live location: $error');
      _failLocation('Could not start location updates. Please try again.');
    }
  }

  void _stopLiveLocation() {
    _testMovementRunning = false;
    _publishNearbyBusinesses(const [], 'paused');

    // Invalidate callbacks before cancelling the native subscription.
    _requestId++;
    _qualityTimer?.cancel();
    _qualityTimer = null;
    _firstFixTimer?.cancel();
    _firstFixTimer = null;
    _locating = false;
    _recenterWhenReady = false;

    final subscription = _positionSubscription;
    _positionSubscription = null;

    if (subscription != null) {
      _pendingStop = _pendingStop.then((_) => subscription.cancel()).catchError(
        (Object error) {
          debugPrint('Could not cancel location subscription: $error');
        },
      );

      debugPrint('Map location updates stopped');
    }
  }

  void _failLocation(String message) {
    _stopLiveLocation();
    if (!mounted) return;

    setState(() {
      _position = null;
      _locationError = message;
    });
  }

  void _centreOnFirstPosition() {
    if (MapTestConfig.enabled && !_recenterWhenReady) return;

    final point = _displayPoint;

    if (!_mapReady || point == null) return;
    if (_centredOnce && !_recenterWhenReady) return;

    _mapController.move(point, _centredOnce ? _mapController.camera.zoom : 16);

    _centredOnce = true;
    _recenterWhenReady = false;
  }

  void _showDemoArea() {
    final centre = MapTestConfig.centre;
    if (!_mapReady || centre == null) return;

    _recenterWhenReady = false;
    _mapController.move(centre, 16);
  }

  void _recenter() {
    if (!_foreground) return;

    if (!_locationAllowed) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Enable location using the notice above the map first.',
          ),
        ),
      );
      return;
    }

    _recenterWhenReady = true;

    if (_displayPoint != null) {
      _centreOnFirstPosition();
    } else {
      // If already waiting, the next reading will recenter the map.
      // Otherwise start a new subscription.
      _readPosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foreground = false;
    _stopLiveLocation();
    _mapController.dispose();
    _businessRequestId++;
    final subscription = _businessSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _businessCampaignRequestId++;

    final businessCampaignSubscription = _businessCampaignSubscription;
    if (businessCampaignSubscription != null) {
      unawaited(businessCampaignSubscription.cancel());
    }

    _landmarkRequestId++;

    final landmarkSubscription = _landmarkSubscription;
    if (landmarkSubscription != null) {
      unawaited(landmarkSubscription.cancel());
    }

    _businessCampaignRequestId++;

    final voucherCampaignSubscription = _businessCampaignSubscription;
    if (voucherCampaignSubscription != null) {
      unawaited(voucherCampaignSubscription.cancel());
    }
    super.dispose();
  }

  void _showDemoCollectionMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _collectDemoReward(RewardMarker reward, String touristId) async {
    if (!mounted || !_foreground || widget.user.id != touristId) {
      return;
    }

    if (_restoringClaims ||
        _claimStorageError != null ||
        _claimSaveInProgress) {
      return;
    }

    // Detect location-stream changes while checking device access.
    final requestId = _requestId;

    bool deviceAccessAllowed;

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      deviceAccessAllowed =
          servicesEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);
    } catch (_) {
      if (mounted && _foreground && widget.user.id == touristId) {
        _showDemoCollectionMessage(
          'Could not verify location access. No demo claim was recorded.',
        );
      }
      return;
    }

    if (!mounted || !_foreground || widget.user.id != touristId) {
      return;
    }

    if (requestId != _requestId) {
      _showDemoCollectionMessage(
        'Location access changed. Wait for a fresh update and try again.',
      );
      return;
    }

    // Read the latest stream position AFTER the asynchronous access checks.
    // Do not reuse the position captured when the preview opened.
    final position = _locationError == null ? _position : null;
    final now = DateTime.now();

    final result = checkRewardCollection(
      reward: reward,
      now: now,
      appIsForeground: _foreground,
      locationAllowed: _locationAllowed && deviceAccessAllowed,
      radiusMeters: _demoCollectionRadiusMeters,
      userLatitude: position?.latitude,
      userLongitude: position?.longitude,
      accuracyMeters: position?.accuracy,
      recordedAt: position?.timestamp,
    );

    if (!result.canProceedToDemo) {
      final message = switch (result.status) {
        RewardCollectionCheckStatus.appInactive =>
          'Return to Discover before collecting.',
        RewardCollectionCheckStatus.rewardUnavailable =>
          'This reward is no longer available.',
        RewardCollectionCheckStatus.locationAccessRequired =>
          'Enable location permission and location services, then try again.',
        RewardCollectionCheckStatus.locationUnavailable =>
          'Wait for a current location update, then try again.',
        RewardCollectionCheckStatus.locationUnreliable =>
          'Your GPS reading is stale or not accurate enough. Try again later.',
        RewardCollectionCheckStatus.invalidCoordinates =>
          'The location coordinates are invalid. No claim was recorded.',
        RewardCollectionCheckStatus.outOfRange =>
          'You are now outside the demo collection radius.',
        RewardCollectionCheckStatus.readyForDemo => '',
      };

      _showDemoCollectionMessage(message);
      return;
    }

    // Recheck after the asynchronous device-access checks.
    if (_restoringClaims ||
        _claimStorageError != null ||
        _claimSaveInProgress) {
      return;
    }

    // Work on a copy. A failed save must not hide the marker or
    // add an unsaved claim to the current in-memory history.
    final candidate = DemoMapClaimStore.fromSnapshot(
      _demoClaims.exportSnapshot(),
    );

    final status = candidate.recordDemoClaim(
      touristId: touristId,
      reward: reward,
      now: now,
    );

    if (status == DemoMapClaimStatus.recorded) {
      _claimSaveInProgress = true;
      setState(() => _savingClaim = true);

      try {
        final saving = _persistDemoCandidate(candidate);

        // Reopened screens can wait for completion.
        // The original future still reports errors below.
        _pendingClaimSave = saving.catchError((Object _) {});

        await saving;
      } catch (_) {
        if (mounted && _foreground && widget.user.id == touristId) {
          _showDemoCollectionMessage(
            'Could not save the demo collection. '
            'No success was confirmed. Tap the marker to retry.',
          );
        }
        return;
      } finally {
        _claimSaveInProgress = false;

        if (mounted) {
          setState(() => _savingClaim = false);
        }
      }

      // The save remains valid if the user left during saving,
      // but do not open a success screen for another account.
      if (!mounted || !_foreground || widget.user.id != touristId) {
        return;
      }

      setState(() {});
    } else if (status == DemoMapClaimStatus.alreadyClaimed) {
      setState(() {});
    }

    if (status == DemoMapClaimStatus.recorded) {
      final claim = _demoClaims
          .claimsFor(touristId)
          .singleWhere((claim) => claim.reward.id == reward.id);

      // Exclude the current claim because the progress card adds it once.
      final previousDemoExp = _demoClaims
          .claimsFor(touristId)
          .where(
            (previous) =>
                previous.reward.type == RewardType.exp &&
                previous.reward.id != reward.id,
          )
          .fold<int>(0, (total, previous) => total + previous.reward.expAmount);

      final accountExp = widget.user.exp < 0 ? 0 : widget.user.exp;
      final demoExpBefore = accountExp + previousDemoExp;
      final currentLevel = widget.user.level;

      bool returningToMap = false;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (successContext) => RewardSuccessScreen(
            claim: claim,
            currentLevel: currentLevel,
            demoExpBefore: demoExpBefore,
            demoTargetExp: 3000,
            onContinue: () {
              // Prevent repeated taps from popping multiple routes.
              if (returningToMap) return;

              returningToMap = true;
              Navigator.of(successContext).pop();
            },
          ),
        ),
      );

      return;
    }

    final message = switch (status) {
      DemoMapClaimStatus.recorded =>
        'Demo collection recorded. No real EXP or voucher was issued.',
      DemoMapClaimStatus.alreadyClaimed =>
        'You already collected this demo reward.',
      DemoMapClaimStatus.rewardUnavailable =>
        'This reward is no longer available.',
      DemoMapClaimStatus.checkpointOnCooldown =>
        'This checkpoint is on cooldown. '
            'Wait 24 hours after your last successful demo collection.',
    };

    _showDemoCollectionMessage(message);
  }

  Future<void> _showRewardDistance(RewardMarker reward) async {
    if (MapMovementTestConfig.enabled) {
      return;
    }
    if (!mounted || !_foreground || _rewardDistanceDialogOpen) {
      return;
    }

    if (_restoringClaims ||
        _claimStorageError != null ||
        _claimSaveInProgress) {
      _showDemoCollectionMessage(
        _claimStorageError ??
            (_claimSaveInProgress
                ? 'Saving your demo collection. Please wait.'
                : 'Loading your demo collection history. Please wait.'),
      );
      return;
    }

    final touristId = widget.user.id;

    if (touristId.trim().isEmpty) {
      _showDemoCollectionMessage(
        'A tourist account is required for demo collection.',
      );
      return;
    }

    if (_demoClaims.hasClaimed(touristId: touristId, spawnId: reward.id)) {
      _showDemoCollectionMessage('You already collected this demo reward.');
      return;
    }

    final eligibleAt = _demoClaims.nextEligibleAt(
      touristId: touristId,
      checkpointId: reward.checkpointId,
    );

    final checkedAt = DateTime.now().toUtc();

    if (eligibleAt != null && checkedAt.isBefore(eligibleAt)) {
      final remaining = eligibleAt.difference(checkedAt);
      final minutes = (remaining.inSeconds / 60).ceil();
      final hours = minutes ~/ 60;
      final leftoverMinutes = minutes % 60;

      _showDemoCollectionMessage(
        'Checkpoint on cooldown. Try again in approximately '
        '${hours}h ${leftoverMinutes}m.',
      );
      return;
    }

    // This dialog reports a snapshot taken when the marker is tapped.
    // Reopen it to check an updated position.
    final now = DateTime.now();
    final position = _position;

    String heading;
    String message;
    double? checkedDistance;
    bool? checkedWithinRange;

    if (!reward.canDisplayAt(now)) {
      heading = 'Reward unavailable';
      message = 'This reward is inactive, expired or no longer displayable.';
    } else if (!_locationAllowed) {
      heading = 'Location access needed';
      message =
          'Enable location permission and location services '
          'before checking your distance.';
    } else if (_locationError != null || position == null) {
      heading = 'Location unavailable';
      message =
          'A current location reading is not available. '
          'Return to the map and wait for an update.';
    } else {
      final quality = assessLocationQuality(
        accuracy: position.accuracy,
        recordedAt: position.timestamp,
        now: now,
      );

      if (quality != LocationQuality.recent) {
        heading = 'Location not reliable enough';
        message = switch (quality) {
          LocationQuality.unavailable => 'Your location is not available yet.',
          LocationQuality.stale =>
            'Your location reading is too old. Wait for a fresh update.',
          LocationQuality.unknownAccuracy =>
            'The accuracy of your location is unknown.',
          LocationQuality.inaccurate =>
            'GPS accuracy is currently too low for a reliable range check.',
          LocationQuality.recent => '',
        };
      } else {
        try {
          final distance = RewardProximity.distanceMeters(
            userLatitude: position.latitude,
            userLongitude: position.longitude,
            rewardLatitude: reward.latitude,
            rewardLongitude: reward.longitude,
          );

          final withinRange = RewardProximity.isWithinRadius(
            distanceMeters: distance,
            radiusMeters: _demoCollectionRadiusMeters,
          );

          checkedDistance = distance;
          checkedWithinRange = withinRange;

          heading = withinRange ? 'Within demo range' : 'Too far away';

          final distanceLabel = distance < 1000
              ? '${distance.toStringAsFixed(1)} m'
              : '${(distance / 1000).toStringAsFixed(2)} km';

          message =
              'Approximate straight-line distance: $distanceLabel\n'
              'Demo radius: '
              '${_demoCollectionRadiusMeters.toStringAsFixed(0)} m\n\n'
              '${withinRange ? 'The distance check passed. This does not yet authorize collection.' : 'You are outside the current demo radius.'}';
        } on ArgumentError {
          heading = 'Distance unavailable';
          message =
              'The location coordinates are invalid. '
              'Return to the map and try again after a new location update.';
        }
      }
    }

    String locationName = reward.locationType == MapLocationType.business
        ? 'this business'
        : 'this landmark';

    for (final location in MockMapData.createLocations()) {
      final recordId = location.businessId ?? location.id;

      if (location.type == reward.locationType &&
          recordId == reward.locationId) {
        locationName = location.title;
        break;
      }
    }

    _rewardDistanceDialogOpen = true;
    bool collectRequested = false;
    bool focusRequested = false;

    try {
      final requestedCollection = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          if (checkedWithinRange == true) {
            return RewardPreviewDialog(
              reward: reward,
              locationName: locationName,
              onCollect: () {
                // Prevent rapid repeated taps from popping more than one route.
                if (collectRequested) return;

                collectRequested = true;
                Navigator.of(dialogContext).pop(true);
              },
            );
          }

          if (checkedWithinRange == false && checkedDistance != null) {
            return OutOfRangeDialog(
              distanceMeters: checkedDistance,
              radiusMeters: _demoCollectionRadiusMeters,
              onGetCloser: () {
                if (focusRequested) return;

                focusRequested = true;
                Navigator.of(dialogContext).pop();
              },
            );
          }

          // Permission, unavailable reward, invalid coordinates or poor GPS:
          // keep an explanatory dialog instead of showing a reward preview.
          return AlertDialog(
            title: Text(heading),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Back to map'),
              ),
            ],
          );
        },
      );

      if (focusRequested &&
          mounted &&
          _foreground &&
          widget.user.id == touristId) {
        _focusOnReward(reward);
        return;
      }

      if (requestedCollection == true &&
          mounted &&
          _foreground &&
          widget.user.id == touristId) {
        await _collectDemoReward(reward, touristId);
      }
    } finally {
      _rewardDistanceDialogOpen = false;
    }
  }

  static Future<void> _loadSharedDemoClaims() async {
    final restoredMapClaims = await _claimPersistence.load();

    final restoredBusinessClaims = await _businessVoucherPersistence.load();

    // Publish only when both histories have loaded successfully.
    _demoClaims = restoredMapClaims;
    _businessVoucherClaims = restoredBusinessClaims;
  }

  Future<void> _restoreDemoClaims() async {
    if (!mounted) return;

    if (!MapTestConfig.enabled) {
      setState(() => _restoringClaims = false);
      return;
    }

    setState(() {
      _restoringClaims = true;
      _claimStorageError = null;
    });

    // Recreated screens share the same initial load.
    final loading = _claimsLoadFuture ??= _loadSharedDemoClaims();

    try {
      await loading;

      // If a previous Discover screen was saving when disposed,
      // wait until its shared history has been updated.
      await _pendingClaimSave;
      await _pendingBusinessVoucherClaim;

      if (!mounted) return;

      setState(() {
        _restoringClaims = false;
        _claimStorageError = null;
      });
      final touristId = widget.user.id;

      if (touristId.trim().isNotEmpty) {
        final claimCount = _businessVoucherClaims.claimsFor(touristId).length;

        debugPrint(
          'Business-voucher demo history loaded: '
          '$claimCount claim(s) for the current tourist.',
        );
      }
    } catch (_) {
      // Allow an explicit retry without deleting the saved data.
      if (identical(_claimsLoadFuture, loading)) {
        _claimsLoadFuture = null;
      }

      if (!mounted) return;

      setState(() {
        _restoringClaims = false;
        _claimStorageError =
            'Could not load demo claim history. '
            'Map-reward collection and business-voucher actions are paused. '
            'Please retry.';
      });
    }
  }

  void _focusOnReward(RewardMarker reward) {
    if (!mounted || !_foreground) return;

    if (!_mapReady) {
      _showDemoCollectionMessage('The map is still loading. Please try again.');
      return;
    }

    if (!reward.canDisplayAt(DateTime.now())) {
      _showDemoCollectionMessage('This reward is no longer available.');
      return;
    }

    // Respect this deliberate camera movement instead of automatically
    // centring on the user when the next location update arrives.
    _centredOnce = true;
    _recenterWhenReady = false;

    _mapController.move(LatLng(reward.latitude, reward.longitude), 17);

    _showDemoCollectionMessage(
      'Showing ${reward.title}. '
      'No walking route is provided. Use a safe, permitted path.',
    );
  }

  static Future<void> _persistDemoCandidate(DemoMapClaimStore candidate) async {
    await _claimPersistence.save(candidate);

    // Publish only after the save completes successfully.
    // This must happen even if the original screen was disposed.
    _demoClaims = candidate;
  }

  void _updateNearbyBusinesses() {
    if (!MapTestConfig.enabled && (_loadingBusinesses || _businessLoadFailed)) {
      _publishNearbyBusinesses(
        const [],
        _businessLoadFailed
            ? 'business data unavailable'
            : 'loading businesses',
      );
      return;
    }

    final point = _discoveryPoint;

    if (point == null) {
      _publishNearbyBusinesses(
        const [],
        'paused: location unavailable or unreliable',
      );
      return;
    }

    final results = findNearbyBusinesses(
      businesses: MapTestConfig.enabled
          ? MockMapData.businesses
          : _liveBusinesses,
      userLatitude: point.latitude,
      userLongitude: point.longitude,
      radiusMeters: _demoBusinessDiscoveryRadiusMeters,
    );

    _publishNearbyBusinesses(results, 'ready');
  }

  void _publishNearbyBusinesses(List<NearbyBusiness> results, String status) {
    _nearbyBusinesses = results;

    if (status == 'ready' && results.isNotEmpty) {
      _scheduleNearbyBusinessPrompt();
    }

    if (!MapTestConfig.enabled) {
      final key =
          'live|$status|${results.map((item) => item.business.id).join(",")}';

      if (_lastNearbyDetectionKey == key) return;
      _lastNearbyDetectionKey = key;

      if (status == 'ready') {
        debugPrint(
          'Live nearby businesses: ${results.length} within '
          '${_demoBusinessDiscoveryRadiusMeters.toStringAsFixed(0)} m',
        );
      } else {
        debugPrint('Live nearby businesses: $status');
      }

      return;
    }

    // Log only status or ordered business-ID changes.
    // Distances still refresh even when no new message is printed.
    final key =
        '$status|${_nearbyBusinesses.map((item) => item.business.id).join(",")}';

    if (_lastNearbyDetectionKey == key) return;
    _lastNearbyDetectionKey = key;

    if (status != 'ready') {
      debugPrint('Nearby businesses: $status');
      return;
    }

    if (_nearbyBusinesses.isEmpty) {
      debugPrint(
        'Nearby businesses: none within '
        '${_demoBusinessDiscoveryRadiusMeters.toStringAsFixed(0)} m',
      );
      return;
    }

    final summary = _nearbyBusinesses
        .map((item) {
          return '${item.business.name} '
              '(approximately ${item.distanceMeters.toStringAsFixed(0)} m)';
        })
        .join(', ');

    debugPrint('Nearby businesses: $summary');
  }

  void _scheduleNearbyBusinessPrompt() {
    if (!mounted || _nearbyPromptScheduled || _nearbyBusinessDialogOpen) {
      return;
    }

    _nearbyPromptScheduled = true;

    // Detection can run inside setState. Open the dialog afterward.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nearbyPromptScheduled = false;

      if (!mounted) return;

      unawaited(_tryShowNearbyBusinessPrompt());
    });
  }

  Future<void> _tryShowNearbyBusinessPrompt() async {
    final demoMode = MapTestConfig.enabled;

    if (!mounted ||
        !_foreground ||
        !_mapReady ||
        !_locationAllowed ||
        _nearbyBusinessDialogOpen ||
        _rewardDistanceDialogOpen ||
        _locationDetailsOpen ||
        _searchOpen ||
        _filterSheetOpen ||
        _restoringMapStyle ||
        _savingMapStyle ||
        (!demoMode && (_loadingBusinesses || _businessLoadFailed)) ||
        (demoMode &&
            (_restoringClaims || _savingClaim || _claimStorageError != null))) {
      return;
    }

    // Do not open over another route, dialog, or bottom sheet.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final touristId = widget.user.id;
    if (touristId.trim().isEmpty) return;

    final now = DateTime.now();
    final nextAllowed = _nextNearbyPromptAt;

    if (nextAllowed != null && now.isBefore(nextAllowed)) return;

    final point = _discoveryPoint;
    if (point == null) return;

    // Recheck proximity immediately before opening the popup.
    final currentNearby = findNearbyBusinesses(
      businesses: demoMode ? MockMapData.businesses : _liveBusinesses,
      userLatitude: point.latitude,
      userLongitude: point.longitude,
      radiusMeters: _demoBusinessDiscoveryRadiusMeters,
    );

    final candidate = _nearbyPromptTracker.nextCandidate(
      touristId: touristId,
      nearby: currentNearby,
    );

    if (candidate == null) return;

    final location = MapLocation.fromBusiness(candidate.business);
    if (location == null || !location.canDisplay) return;

    final voucherOffers = demoMode
        ? _demoBusinessOffers(candidate.business)
        : <MapVoucherOffer>[];

    _nearbyBusinessDialogOpen = true;
    bool actionTaken = false;
    var previewOpen = true;

    try {
      final requestedDetails = showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          void closeWith(bool viewDetails) {
            if (actionTaken) return;
            actionTaken = true;
            Navigator.of(dialogContext).pop(viewDetails);
          }

          if (!demoMode) {
            final business = candidate.business;

            return AlertDialog(
              icon: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFF3267D8),
                size: 36,
              ),
              title: Text(
                MapMovementTestConfig.enabled
                    ? 'Business nearby · TEST LOCATION'
                    : 'Business nearby',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      business.category.trim().isEmpty
                          ? 'Uncategorised'
                          : business.category,
                    ),
                    if (business.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(business.address),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Approximately '
                      '${candidate.distanceMeters.toStringAsFixed(0)} m '
                      'away in a straight line when detected.',
                    ),
                    const SizedBox(height: 12),
                    _buildLiveBusinessPromotionSection(business, compact: true),
                    const SizedBox(height: 12),
                    _buildLiveBusinessVoucherSection(
                      business,
                      onSelected: (campaign) {
                        unawaited(
                          _showLiveBusinessVoucherDetails(
                            business: business,
                            campaign: campaign,
                            onRecorded: () => closeWith(false),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => closeWith(false),
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: () => closeWith(true),
                  child: const Text('View details'),
                ),
              ],
            );
          }

          return NearbyBusinessDialog(
            business: candidate.business,
            distanceMeters: candidate.distanceMeters,
            offers: voucherOffers,
            onDismiss: () => closeWith(false),
            onViewDetails: () => closeWith(true),
            onCheckEligibility: (voucherId) {
              return _checkSelectedBusinessVoucher(
                touristId: touristId,
                businessId: candidate.business.id,
                voucherId: voucherId,
                offers: voucherOffers,
              );
            },
            onClaim: (voucherId) {
              return _claimSelectedBusinessVoucher(
                touristId: touristId,
                businessId: candidate.business.id,
                voucherId: voucherId,
                offers: voucherOffers,
                isPreviewOpen: () => previewOpen && !actionTaken,
              );
            },
          );
        },
      );

      // The dialog route has now been opened.
      // Dismissing it still counts as having seen this reminder.
      _nearbyPromptTracker.markShown(
        touristId: touristId,
        businessId: candidate.business.id,
      );

      final viewDetails = await requestedDetails;
      previewOpen = false;

      if (viewDetails == true &&
          mounted &&
          _foreground &&
          widget.user.id == touristId &&
          ModalRoute.of(context)?.isCurrent == true) {
        await _showLocationDetails(location);
      }
    } finally {
      previewOpen = false;
      _nearbyBusinessDialogOpen = false;
      _nextNearbyPromptAt = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  Future<BusinessVoucherClaimStatus> _checkSelectedBusinessVoucher({
    required String touristId,
    required String businessId,
    required String voucherId,
    required List<MapVoucherOffer> offers,
  }) async {
    if (MapMovementTestConfig.enabled) {
      return BusinessVoucherClaimStatus.locationUnavailable;
    }

    if (!mounted || !_foreground) {
      return BusinessVoucherClaimStatus.appInactive;
    }

    if (touristId.trim().isEmpty || widget.user.id != touristId) {
      return BusinessVoucherClaimStatus.accountRequired;
    }

    if (_restoringClaims || _claimStorageError != null) {
      return BusinessVoucherClaimStatus.historyUnavailable;
    }

    final requestId = _requestId;

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    if (!mounted || !_foreground) {
      return BusinessVoucherClaimStatus.appInactive;
    }

    if (widget.user.id != touristId) {
      return BusinessVoucherClaimStatus.accountRequired;
    }

    final accessAllowed =
        _locationAllowed &&
        servicesEnabled &&
        (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always);

    if (!accessAllowed) {
      return BusinessVoucherClaimStatus.locationAccessRequired;
    }

    if (requestId != _requestId) {
      return BusinessVoucherClaimStatus.locationUnavailable;
    }

    Business? currentBusiness;

    for (final business in MockMapData.businesses) {
      if (business.id == businessId) {
        currentBusiness = business;
        break;
      }
    }

    if (currentBusiness == null) {
      return BusinessVoucherClaimStatus.voucherUnavailable;
    }

    // Use the latest stream reading after checking device access.
    final position = _locationError == null ? _position : null;

    // Recheck after the asynchronous device-permission checks.
    if (_restoringClaims || _claimStorageError != null) {
      return BusinessVoucherClaimStatus.historyUnavailable;
    }

    return checkBusinessVoucherClaim(
      touristId: touristId,
      business: currentBusiness,
      selectedVoucherId: voucherId,
      currentOffers: offers,
      now: DateTime.now(),
      appIsForeground: _foreground,
      locationAllowed: accessAllowed,
      radiusMeters: _demoBusinessVoucherClaimRadiusMeters,
      userLatitude: position?.latitude,
      userLongitude: position?.longitude,
      accuracyMeters: position?.accuracy,
      recordedAt: position?.timestamp,
      hasAlreadyClaimed:
          voucherId.trim().isNotEmpty &&
          _businessVoucherClaims.hasClaimed(
            touristId: touristId,
            offerId: voucherId,
          ),
    );
  }

  Future<BusinessVoucherClaimStatus> _claimSelectedBusinessVoucher({
    required String touristId,
    required String businessId,
    required String voucherId,
    required List<MapVoucherOffer> offers,
    required bool Function() isPreviewOpen,
  }) {
    if (_businessVoucherClaimInProgress) {
      return Future.value(BusinessVoucherClaimStatus.claimInProgress);
    }

    // Lock before any asynchronous work starts.
    _businessVoucherClaimInProgress = true;

    final operation = _performBusinessVoucherClaim(
      touristId: touristId,
      businessId: businessId,
      voucherId: voucherId,
      offers: offers,
      isPreviewOpen: isPreviewOpen,
    );

    // Recreated screens can safely await completion.
    // The original operation still delivers errors to its caller.
    _pendingBusinessVoucherClaim = operation
        .then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {})
        .whenComplete(() {
          _businessVoucherClaimInProgress = false;
        });

    return operation;
  }

  Future<BusinessVoucherClaimStatus> _performBusinessVoucherClaim({
    required String touristId,
    required String businessId,
    required String voucherId,
    required List<MapVoucherOffer> offers,
    required bool Function() isPreviewOpen,
  }) async {
    if (MapMovementTestConfig.enabled) {
      return BusinessVoucherClaimStatus.locationUnavailable;
    }
    if (!MapTestConfig.enabled || !isPreviewOpen()) {
      return BusinessVoucherClaimStatus.appInactive;
    }

    // Always run fresh checks when Claim is tapped.
    final eligibility = await _checkSelectedBusinessVoucher(
      touristId: touristId,
      businessId: businessId,
      voucherId: voucherId,
      offers: offers,
    );

    if (eligibility != BusinessVoucherClaimStatus.readyForDemo) {
      return eligibility;
    }

    if (!mounted || !_foreground || !isPreviewOpen()) {
      return BusinessVoucherClaimStatus.appInactive;
    }

    if (widget.user.id != touristId) {
      return BusinessVoucherClaimStatus.accountRequired;
    }

    if (_restoringClaims || _claimStorageError != null) {
      return BusinessVoucherClaimStatus.historyUnavailable;
    }

    final businesses = MockMapData.businesses
        .where((business) => business.id == businessId)
        .toList();

    final selectedOffers = offers
        .where((offer) => offer.id == voucherId)
        .toList();

    if (businesses.length != 1 || selectedOffers.length != 1) {
      return BusinessVoucherClaimStatus.voucherUnavailable;
    }

    try {
      final result = await _businessVoucherPersistence.recordAndSave(
        currentStore: _businessVoucherClaims,
        touristId: touristId,
        business: businesses.single,
        offer: selectedOffers.single,
        now: DateTime.now(),
      );

      // Publish saved history even if the original screen was closed.
      // Otherwise another screen could use outdated eligibility.
      if (result.status == DemoBusinessVoucherClaimStatus.recorded) {
        _businessVoucherClaims = result.store;
      }

      if (!mounted || !_foreground || !isPreviewOpen()) {
        return BusinessVoucherClaimStatus.appInactive;
      }

      if (widget.user.id != touristId) {
        return BusinessVoucherClaimStatus.accountRequired;
      }

      return switch (result.status) {
        DemoBusinessVoucherClaimStatus.recorded =>
          BusinessVoucherClaimStatus.demoRecorded,
        DemoBusinessVoucherClaimStatus.alreadyClaimed =>
          BusinessVoucherClaimStatus.alreadyClaimed,
        DemoBusinessVoucherClaimStatus.unavailable =>
          BusinessVoucherClaimStatus.voucherUnavailable,
      };
    } catch (_) {
      return BusinessVoucherClaimStatus.saveFailed;
    }
  }

  List<MapVoucherOffer> _demoBusinessOffers(Business business) {
    final checkedAt = DateTime.now();

    final multipleOffers =
        MapTestConfig.enabled &&
        const bool.fromEnvironment('MAP_DEMO_MULTIPLE_VOUCHERS');

    const testTag = String.fromEnvironment(
      'MAP_DEMO_BUSINESS_VOUCHER_TEST_TAG',
    );

    return [
      ...MockMapData.createDemoVoucherOffers(checkedAt),
      if (multipleOffers)
        MapVoucherOffer(
          id:
              'debug-second-offer-${business.id}'
              '${testTag.isEmpty ? '' : '-$testTag'}',
          businessId: business.id,
          title: 'Second demo voucher — short offer',
          validFrom: checkedAt.subtract(const Duration(minutes: 1)),
          expiresAt: checkedAt.add(const Duration(minutes: 5)),
          remainingStock: 5,
          mapEligible: false,
        ),
    ];
  }

  void _retryLiveBusinesses() {
    setState(_startLiveBusinesses);
  }

  Marker _buildNamedPlaceMarker(MapLocation location) {
    final isBusiness = location.type == MapLocationType.business;

    return Marker(
      key: ValueKey('live:${location.id}'),
      point: LatLng(location.latitude, location.longitude),
      width: 160,
      height: 116,
      alignment: Alignment.center,
      rotate: true,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 32,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 3),
                    ],
                  ),
                  child: Text(
                    location.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF19243D),
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: Tooltip(
                message: location.title,
                child: Material(
                  color: isBusiness
                      ? const Color(0xFF467A45)
                      : const Color(0xFF7656A3),
                  elevation: 3,
                  shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => unawaited(_showLocationDetails(location)),
                    child: Icon(
                      isBusiness
                          ? Icons.storefront_outlined
                          : Icons.account_balance_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBusinessLayer() {
    final waiting = _loadingBusinesses;
    final failed = _businessLoadFailed;
    final locations = filterMapLocations(
      _liveLocations,
      _selectedBusinessCategory,
    );

    return Stack(
      children: [
        MarkerLayer(
          markers: [
            for (final location in locations) _buildNamedPlaceMarker(location),
          ],
        ),
        if (waiting || failed || _loadingLandmarks || _landmarkLoadFailed)
          Positioned(
            left: 16,
            right: 84,
            bottom: 150,
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
                    if (waiting || _loadingLandmarks) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                    ],
                    if (waiting) const Text('Loading businesses…'),
                    if (_loadingLandmarks) const Text('Loading landmarks…'),
                    if (failed) ...[
                      const Text(
                        'Could not load businesses. '
                        'Check your connection and sign-in.',
                      ),
                      TextButton(
                        onPressed: _retryLiveBusinesses,
                        child: const Text('Retry businesses'),
                      ),
                    ],
                    if (_landmarkLoadFailed) ...[
                      const Text(
                        'Could not load landmarks. '
                        'Check your connection and permissions.',
                      ),
                      TextButton(
                        onPressed: () => setState(_startLiveLandmarks),
                        child: const Text('Retry landmarks'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _startLiveBusinesses() {
    final requestId = ++_businessRequestId;
    final previous = _businessSubscription;

    if (previous != null) {
      unawaited(previous.cancel());
    }

    _liveLocations = const [];
    _loadingBusinesses = true;
    _businessLoadFailed = false;
    _updateNearbyBusinesses();

    _businessSubscription = MapRepository().watchActiveBusinesses().listen(
      (businesses) {
        if (!mounted || requestId != _businessRequestId) return;

        setState(() {
          _liveBusinesses = List<Business>.unmodifiable(businesses);
          _liveLocations = businesses
              .map(MapLocation.fromBusiness)
              .whereType<MapLocation>()
              .where((location) => location.canDisplay)
              .toList(growable: false);

          _loadingBusinesses = false;
          _businessLoadFailed = false;
          _updateNearbyBusinesses();
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || requestId != _businessRequestId) return;

        setState(() {
          _liveLocations = const [];
          _loadingBusinesses = false;
          _businessLoadFailed = true;
          _updateNearbyBusinesses();
        });
      },
    );
  }

  Widget _buildLiveLandmarkLayer() {
    return MarkerLayer(
      markers: [
        for (final location in filterMapLocations(
          _liveLandmarks,
          null,
          selectedLandmarkCategory: _selectedLandmarkCategory,
        ))
          _buildNamedPlaceMarker(location),
      ],
    );
  }

  static const double _liveExpCollectionRadiusMeters = 50;

  void _startLiveBusinessCampaigns() {
    final requestId = ++_businessCampaignRequestId;
    final previous = _businessCampaignSubscription;

    if (previous != null) {
      unawaited(previous.cancel());
    }

    _liveBusinessCampaigns = const [];
    _loadingBusinessCampaigns = true;
    _businessCampaignLoadFailed = false;

    _businessCampaignSubscription = MapRepository()
        .watchActiveBusinessCampaigns()
        .listen(
          (campaigns) {
            if (!mounted || requestId != _businessCampaignRequestId) return;

            setState(() {
              _liveBusinessCampaigns = campaigns;
              _loadingBusinessCampaigns = false;
              _businessCampaignLoadFailed = false;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted || requestId != _businessCampaignRequestId) return;

            setState(() {
              _liveBusinessCampaigns = const [];
              _loadingBusinessCampaigns = false;
              _businessCampaignLoadFailed = true;
            });

            debugPrint('Map: business campaign loading failed: $error');
          },
        );
  }

  Widget _buildLiveBusinessVoucherSection(
    Business business, {
    ValueChanged<Campaign>? onSelected,
  }) {
    if (_loadingBusinessCampaigns) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading available vouchers…'),
          ],
        ),
      );
    }

    if (_businessCampaignLoadFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available vouchers could not be loaded.'),
          TextButton(
            onPressed: () => setState(_startLiveBusinessCampaigns),
            child: const Text('Retry vouchers'),
          ),
        ],
      );
    }

    return LiveBusinessVoucherSection(
      business: business,
      campaigns: _liveBusinessCampaigns,
      checkedAt: DateTime.now(),
      onSelected: onSelected,
    );
  }

  Widget _buildLiveBusinessPromotionSection(
    Business business, {
    bool compact = false,
  }) {
    if (_loadingBusinessCampaigns || _businessCampaignLoadFailed) {
      return const SizedBox.shrink();
    }

    return LiveBusinessPromotionSection(
      business: business,
      campaigns: _liveBusinessCampaigns,
      checkedAt: DateTime.now(),
      compact: compact,
    );
  }

  Future<LiveRewardCollectionCheck> _checkLiveExpAvailability(
    RewardMarker selectedReward,
    List<RewardMarker> Function(DateTime instant) currentRewardsAt,
    bool Function() rewardSourceReady,
  ) async {
    final touristId = widget.user.id;
    final requestId = _requestId;
    final simulationActive = MapMovementTestConfig.enabled;

    bool deviceAccessAllowed;

    if (simulationActive) {
      deviceAccessAllowed = _displayPoint != null;
    } else {
      try {
        final servicesEnabled = await Geolocator.isLocationServiceEnabled();
        final permission = await Geolocator.checkPermission();

        deviceAccessAllowed =
            servicesEnabled &&
            (permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always);
      } catch (_) {
        deviceAccessAllowed = false;
      }
    }

    if (!mounted || !_foreground || widget.user.id != touristId) {
      return const LiveRewardCollectionCheck(
        LiveRewardCollectionStatus.localCheckFailed,
        localCheck: RewardCollectionCheck(
          status: RewardCollectionCheckStatus.appInactive,
        ),
      );
    }

    if (requestId != _requestId) {
      return const LiveRewardCollectionCheck(
        LiveRewardCollectionStatus.localCheckFailed,
        localCheck: RewardCollectionCheck(
          status: RewardCollectionCheckStatus.locationUnavailable,
        ),
      );
    }

    final sourceReady =
        !_loadingBusinesses &&
        !_businessLoadFailed &&
        !_loadingLandmarks &&
        !_landmarkLoadFailed &&
        rewardSourceReady();

    final now = DateTime.now();
    final simulatedPoint = simulationActive ? _displayPoint : null;
    final position = !simulationActive && _locationError == null
        ? _position
        : null;

    return checkLiveRewardCollection(
      selectedReward: selectedReward,
      currentRewards: sourceReady
          ? currentRewardsAt(now)
          : const <RewardMarker>[],
      sourceReady: sourceReady,

      // Simulation was intentionally enabled through the development UI.
      simulationActive: false,

      now: now,
      appIsForeground: _foreground,
      locationAllowed: simulationActive
          ? simulatedPoint != null
          : _locationAllowed && deviceAccessAllowed,
      radiusMeters: _liveExpCollectionRadiusMeters,
      userLatitude: simulatedPoint?.latitude ?? position?.latitude,
      userLongitude: simulatedPoint?.longitude ?? position?.longitude,
      accuracyMeters: simulationActive ? 1 : position?.accuracy,
      recordedAt: simulationActive ? now : position?.timestamp,
    );
  }

  Future<void> _showLiveBusinessVoucherDetails({
    required Business business,
    required Campaign campaign,
    required VoidCallback onRecorded,
  }) async {
    if (!mounted || !_foreground || _liveBusinessVoucherDetailsOpen) {
      return;
    }

    _liveBusinessVoucherDetailsOpen = true;

    try {
      final result = await showDialog<LiveBusinessVoucherClaimResult>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) {
          return LiveBusinessVoucherDetailsDialog(
            campaign: campaign,
            onCheck: () {
              return _checkLiveBusinessVoucherClaim(
                business: business,
                campaign: campaign,
              );
            },
            onClaim: () {
              return _claimLiveBusinessVoucher(
                business: business,
                campaign: campaign,
              );
            },
          );
        },
      );

      if (!mounted ||
          result == null ||
          result.status != LiveBusinessVoucherClaimStatus.recorded) {
        return;
      }

      // Close the nearby popup or business-details sheet underneath.
      onRecorded();

      // Let the previous modal finish closing before opening success.
      await Future<void>.delayed(Duration.zero);

      if (!mounted || !_foreground) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (successContext) {
            return RewardSuccessScreen.businessVoucher(
              result: result,
              onContinue: () {
                Navigator.of(successContext).pop();
              },
            );
          },
        ),
      );
    } finally {
      _liveBusinessVoucherDetailsOpen = false;
    }
  }

  Future<LiveBusinessVoucherCollectionCheck> _checkLiveBusinessVoucherClaim({
    required Business business,
    required Campaign campaign,
  }) async {
    final now = DateTime.now();
    final simulationActive = MapMovementTestConfig.enabled;
    final simulatedPoint = simulationActive ? _displayPoint : null;
    final position = simulationActive ? null : _position;

    return checkLiveBusinessVoucherCollection(
      touristId: widget.user.id,
      business: business,
      voucherId: campaign.id,
      currentCampaigns: _liveBusinessCampaigns,
      now: now,
      appIsForeground: mounted && _foreground,
      locationAllowed: _locationAllowed,
      radiusMeters: _liveBusinessVoucherClaimRadiusMeters,
      userLatitude: simulationActive
          ? simulatedPoint?.latitude
          : position?.latitude,
      userLongitude: simulationActive
          ? simulatedPoint?.longitude
          : position?.longitude,
      accuracyMeters: simulationActive
          ? simulatedPoint == null
                ? null
                : 1
          : position?.accuracy,
      recordedAt: simulationActive
          ? simulatedPoint == null
                ? null
                : now
          : position?.timestamp,
    );
  }

  Future<LiveBusinessVoucherClaimResult> _claimLiveBusinessVoucher({
    required Business business,
    required Campaign campaign,
  }) {
    return _liveBusinessVoucherClaimService.claim(
      uid: widget.user.id,
      businessId: business.id,
      voucherId: campaign.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final point = _displayPoint;

    final accuracy = position?.accuracy;
    final hasAccuracy = accuracy != null && accuracy.isFinite && accuracy > 0;

    final quality = assessLocationQuality(
      accuracy: accuracy,
      recordedAt: position?.timestamp,
      now: DateTime.now(),
    );

    final qualityMessage = switch (quality) {
      LocationQuality.unavailable => 'Your location is not available yet.',
      LocationQuality.stale =>
        'Showing an older location reading. '
            'Waiting for a new update.',
      LocationQuality.unknownAccuracy =>
        'Location accuracy is unavailable. '
            'Treat this position as approximate.',
      LocationQuality.inaccurate =>
        'Low location accuracy: about '
            '${accuracy!.toStringAsFixed(0)} m. '
            'Try somewhere with a clearer view of the sky.',
      LocationQuality.recent =>
        'Latest location · estimated accuracy: '
            '${accuracy!.toStringAsFixed(0)} m',
    };

    final showQualityWarning =
        position != null && quality != LocationQuality.recent;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: MapTestConfig.centre ?? _initialPosition,
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _centreOnFirstPosition();
                }
              });
            },
          ),
          children: [
            MapTilesWithStatus(key: ValueKey(_mapStyle), style: _mapStyle),

            if (!MapTestConfig.enabled) _buildLiveLandmarkLayer(),
            if (!MapTestConfig.enabled) _buildLiveBusinessLayer(),

            if (!MapTestConfig.enabled)
              LiveExpPreviewLayer(
                key: ValueKey('live-reward-previews:${widget.user.id}'),
                businesses: !_loadingBusinesses && !_businessLoadFailed
                    ? _liveBusinesses
                    : const <Business>[],
                places: [
                  if (!_loadingBusinesses && !_businessLoadFailed)
                    ..._liveLocations,
                  if (!_loadingLandmarks && !_landmarkLoadFailed)
                    ..._liveLandmarks,
                ],
                onCheckExpAvailability: _checkLiveExpAvailability,
                collectionRadiusMeters: _liveExpCollectionRadiusMeters,
                onFocusReward: _focusOnReward,
                userId: widget.user.id,
              ),

            if (MapTestConfig.enabled &&
                !_restoringClaims &&
                _claimStorageError == null)
              DemoMapMarkers(
                selectedCategory: _selectedBusinessCategory,
                selectedLandmarkCategory: _selectedLandmarkCategory,
                onLocationSelected: _showLocationDetails,
                onRewardSelected: _showRewardDistance,
                hiddenRewardIds: widget.user.id.trim().isEmpty
                    ? const <String>{}
                    : _demoClaims
                          .claimsFor(widget.user.id)
                          .map((claim) => claim.reward.id)
                          .toSet(),
              ),

            // Accuracy is measured in metres, not screen pixels.
            if (point != null && hasAccuracy)
              IgnorePointer(
                child: CircleLayer(
                  circles: [
                    CircleMarker(
                      point: point,
                      radius: accuracy,
                      useRadiusInMeter: true,
                      color: const Color(0x223267D8),
                      borderColor: const Color(0x663267D8),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              ),

            if (point != null)
              IgnorePointer(
                child: MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 120,
                      height: 120,
                      alignment: Alignment.center,
                      rotate: false,
                      child: MapMovementTestConfig.enabled
                          ? const Icon(
                              Icons.person_pin_circle,
                              color: Colors.deepOrange,
                              size: 48,
                            )
                          : const CompassUserMarker(),
                    ),
                  ],
                ),
              ),
          ],
        ),

        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: MapProgressCard(user: widget.user),
        ),

        Positioned(
          top: 130,
          left: 16,
          right: 84,
          child: MapLocationPermission(onAccessChanged: _onAccessChanged),
        ),

        // The permission notice is hidden when access is granted,
        // so this status card can use the same space.
        if (MapMovementTestConfig.enabled && _locationAllowed)
          Positioned(
            top: 130,
            left: 16,
            right: 84,
            child: MapTestMovementControls(
              enabled: _foreground && _testMovementRunning && _mapReady,
              stepMeters: MapMovementTestConfig.stepMeters,
              onMove: (direction) {
                _changeTestPosition(direction: direction);
              },
              onReset: () => _changeTestPosition(),
            ),
          ),

        if (_locationAllowed && !MapMovementTestConfig.enabled)
          Positioned(
            top: 130,
            left: 16,
            right: 84,
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
                      _locating
                          ? 'Finding your location…'
                          : _locationError ?? qualityMessage,
                      style: TextStyle(
                        color: showQualityWarning && _locationError == null
                            ? const Color(0xFF8A4B00)
                            : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    if (_locationError != null && !_locating)
                      TextButton(
                        onPressed: _readPosition,
                        child: const Text('Retry location'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (MapTestConfig.enabled &&
            (_restoringClaims || _savingClaim || _claimStorageError != null))
          Positioned.fill(
            child: Stack(
              children: [
                const ModalBarrier(
                  dismissible: false,
                  color: Color(0x33000000),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_claimStorageError == null) ...[
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              _claimStorageError ??
                                  (_savingClaim
                                      ? 'Saving demo collection…'
                                      : 'Loading demo claim histories…'),
                              textAlign: TextAlign.center,
                            ),
                            if (_claimStorageError != null) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _restoreDemoClaims,
                                child: const Text('Retry'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Positioned(
          top: 130,
          bottom: 150,
          right: 16,
          child: Center(
            child: MapActionButtons(
              onCurrentLocation: _recenter,
              onMapStyle: _selectMapStyle,
              onSearch: _openMapSearch,
              onFilter: _selectBusinessCategory,
              filterActive:
                  _selectedBusinessCategory != null ||
                  _selectedLandmarkCategory != null,
              onDemoArea: MapTestConfig.enabled ? _showDemoArea : null,
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 110,
          child: MapAttribution(style: _mapStyle),
        ),
      ],
    );
  }
}
