import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_test_config.dart';

import '../../data/mock_map_data.dart';

import '../../models/map_location.dart';
import '../../models/localquest_models.dart';

import '../../services/map_category_filter.dart';

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

class InteractiveMapScreen extends StatefulWidget {
  const InteractiveMapScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<InteractiveMapScreen> createState() =>
      _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen>
    with WidgetsBindingObserver {
  static const _initialPosition = LatLng(3.1390, 101.6869);

  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _firstFixTimer;
  Timer? _qualityTimer;
  Future<void> _pendingStop = Future<void>.value();
  MapStyle _mapStyle = MapStyle.standard;

  Position? _position;
  String? _selectedBusinessCategory;
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
  String? _locationError;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;

    unawaited(_restoreMapStyle());
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
    return mounted &&
        _foreground &&
        _locationAllowed &&
        id == _requestId;
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final style in MapStyle.values)
                  ListTile(
                    enabled: style == MapStyle.standard ||
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

    if (selected == MapStyle.satellite &&
        !MapStyleConfig.satelliteAvailable) {
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

    if (!MapTestConfig.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Demo search requires your development configuration. '
            'Live place search is not connected yet.',
          ),
        ),
      );
      return;
    }

    _searchOpen = true;

    try {
      final selected = await showSearch<MapLocation?>(
        context: context,
        delegate: MapSearchDelegate(
          locations: filterMapLocations(
            MockMapData.createLocations(),
            _selectedBusinessCategory,
          ),
        ),
      );

      if (!mounted ||
          !_mapReady ||
          selected == null ||
          !selected.canDisplay) {
        return;
      }

      // Do not let the next initial GPS fix override this selection.
      _centredOnce = true;
      _recenterWhenReady = false;

      _mapController.move(
        LatLng(selected.latitude, selected.longitude),
        17,
      );

      await _showLocationDetails(selected);

    } finally {
      _searchOpen = false;
    }
  }

  Future<void> _selectBusinessCategory() async {
    if (!MapTestConfig.enabled || _filterSheetOpen) return;

    _filterSheetOpen = true;

    try {
      final categories = availableBusinessCategories(
        MockMapData.createLocations(),
      );

      final selected = await showModalBottomSheet<String>(
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
                    child: Column(
                      children: [
                        Text(
                          'Filter businesses',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Applies to business markers and search. '
                          'Landmarks and rewards stay visible.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.apps),
                    title: const Text('All businesses'),
                    subtitle: const Text('Clear the category filter'),
                    trailing: _selectedBusinessCategory == null
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    // Empty string means clear. Null means cancelled.
                    onTap: () => Navigator.of(sheetContext).pop(''),
                  ),
                  for (final category in categories)
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(category),
                      trailing: _selectedBusinessCategory == category
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(category),
                    ),
                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No business categories are available.'),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || selected == null) return;

      setState(() {
        _selectedBusinessCategory = selected.isEmpty ? null : selected;
      });
    } finally {
      _filterSheetOpen = false;
    }
  }

Future<void> _showLocationDetails(MapLocation location) async {
    if (!mounted || _locationDetailsOpen || !location.canDisplay) return;

    _locationDetailsOpen = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: 0.85,
            child: MapLocationDetails(
              location: location,
              onClose: () => Navigator.of(sheetContext).pop(),
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

      final granted = permission == LocationPermission.whileInUse ||
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

      _positionSubscription = Geolocator.getPositionStream(
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
        setState(() {});
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
      _pendingStop = _pendingStop
          .then((_) => subscription.cancel())
          .catchError((Object error) {
        debugPrint('Could not cancel location subscription: $error');
      });

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
    // Keep the demo area visible until the user requests GPS recentering.
    if (MapTestConfig.enabled && !_recenterWhenReady) return;

    final position = _position;

    if (!_mapReady || position == null) return;
    if (_centredOnce && !_recenterWhenReady) return;

    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _centredOnce ? _mapController.camera.zoom : 16,
    );

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

    if (_position != null) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final point = position == null
        ? null
        : LatLng(position.latitude, position.longitude);

    final accuracy = position?.accuracy;
    final hasAccuracy =
    accuracy != null && accuracy.isFinite && accuracy > 0;

    final quality = assessLocationQuality(
      accuracy: accuracy,
      recordedAt: position?.timestamp,
      now: DateTime.now(),
    );

    final qualityMessage = switch (quality) {
      LocationQuality.unavailable =>
        'Your location is not available yet.',
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

    final showQualityWarning = position != null &&
        quality != LocationQuality.recent;

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
            MapTilesWithStatus(
              key: ValueKey(_mapStyle),
              style: _mapStyle,
            ),

            if (MapTestConfig.enabled)
              DemoMapMarkers(
                selectedCategory: _selectedBusinessCategory,
                onLocationSelected: _showLocationDetails,
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
                      child: const CompassUserMarker(),
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
          child: MapLocationPermission(
            onAccessChanged: _onAccessChanged,
          ),
        ),

        // The permission notice is hidden when access is granted,
        // so this status card can use the same space.
        if (_locationAllowed)
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

        Positioned(
          top: 130,
          bottom: 150,
          right: 16,
          child: Center(
            child: MapActionButtons(
              onCurrentLocation: _recenter,
              onMapStyle: _selectMapStyle,
              onSearch: _openMapSearch,
              onFilter: MapTestConfig.enabled ? _selectBusinessCategory : null,
              filterActive: _selectedBusinessCategory != null,
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