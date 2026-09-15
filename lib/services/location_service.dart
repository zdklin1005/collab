import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/demo_database_seeder.dart';
import '../data/mock_map_data.dart';
import '../models/localquest_models.dart';
import 'localquest_services.dart';
import 'reward_proximity.dart';

/// Automatic location tracker that monitors the tourist's GPS position
/// and automatically records visits exclusively when the tourist enters the
/// vicinity of a registered LocalQuest partner business.
class LocationTrackerService {
  LocationTrackerService({
    UserRepository? userRepository,
    MerchantRepository? merchantRepository,
  })  : _userRepository = userRepository ?? UserRepository.instance,
        _merchantRepository = merchantRepository ?? MerchantRepository.instance;

  static final LocationTrackerService instance = LocationTrackerService();

  final UserRepository _userRepository;
  final MerchantRepository _merchantRepository;

  StreamSubscription<Position>? _positionSubscription;
  String? _activeUserId;
  Position? _lastPosition;

  final ValueNotifier<bool> isTrackingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLocationHistoryEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> lastVisitedBusinessNotifier = ValueNotifier<String?>(null);

  bool get isTracking => isTrackingNotifier.value;
  bool get isLocationHistoryEnabled => isLocationHistoryEnabledNotifier.value;
  Position? get lastPosition => _lastPosition;
  String? get activeUserId => _activeUserId;

  void setLocationHistoryEnabled(bool enabled) {
    isLocationHistoryEnabledNotifier.value = enabled;
    if (!enabled) {
      stopTracking();
    }
  }

  /// Cooldown per business ID to prevent recording multiple times while staying at a venue.
  /// Set to 15 minutes and departure-aware, so visiting other places or returning after
  /// leaving records the new visit without spamming while sitting at the same table.
  final Map<String, DateTime> _recentVisits = {};
  static const Duration visitCooldown = Duration(minutes: 15);

  /// Tracks the currently active dwell business ID so continuous GPS pings while
  /// sitting at the same place don't spam the history.
  String? _currentlyDwellingBusinessId;

  /// Concurrency mutex to prevent parallel async position processing race conditions.
  bool _isProcessingPosition = false;

  /// Radius in meters for automatic vicinity detection to a registered business.
  static const double vicinityRadiusMeters = 75.0;

  /// Callback when a registered business visit is automatically logged.
  void Function(Business business)? onBusinessVisitDetected;

  // --------------------------------------------------------------------------
  // Test Injection Hooks
  // --------------------------------------------------------------------------
  Stream<Position> Function()? mockPositionStream;
  Future<Position> Function()? mockGetCurrentPosition;
  Future<bool> Function()? mockCheckPermission;
  List<Business>? mockRegisteredBusinesses;

  void clearRecentVisits() {
    _recentVisits.clear();
    _currentlyDwellingBusinessId = null;
    _isProcessingPosition = false;
    lastVisitedBusinessNotifier.value = null;
  }

  // --------------------------------------------------------------------------
  // Registered Businesses Data Fetching
  // --------------------------------------------------------------------------

  /// Retrieve active registered businesses from Firestore (and MockMapData for development/testing).
  Future<List<Business>> getRegisteredBusinesses() async {
    if (mockRegisteredBusinesses != null) {
      return mockRegisteredBusinesses!;
    }

    final businesses = <Business>[];

    // Add developer mock businesses (e.g. Demo Local Café, Demo Artisan Shop)
    businesses.addAll(MockMapData.businesses);

    // Fetch active registered businesses from Firestore
    try {
      final snap = await _merchantRepository.db
          .collection('businesses')
          .where('active', isEqualTo: true)
          .limit(100)
          .get();

      for (final doc in snap.docs) {
        final b = Business.fromDoc(doc);
        if (b.latitude != null && b.longitude != null) {
          if (!businesses.any((existing) => existing.id == b.id)) {
            businesses.add(b);
          }
        }
      }
    } catch (_) {
      // Offline fallback
    }

    // Always include authentic Penang partner establishments as verified defaults
    for (final seed in DemoDatabaseSeeder.sampleMalaysianBusinesses) {
      if (!businesses.any((existing) => existing.id == seed.id)) {
        businesses.add(seed.toBusiness());
      }
    }

    return businesses;
  }

  /// For interactive verification and automated diagnostic testing:
  /// Simulates the tourist's GPS arrival at a specific [businessId].
  Future<bool> simulateArrival({
    required String businessId,
    required String userId,
  }) async {
    if (!isLocationHistoryEnabledNotifier.value) {
      return false;
    }

    final businesses = await getRegisteredBusinesses();
    final target = businesses.where((b) => b.id == businessId).firstOrNull;
    if (target == null || target.latitude == null || target.longitude == null) {
      return false;
    }

    final simulatedPosition = Position(
      latitude: target.latitude!,
      longitude: target.longitude!,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    return processPosition(simulatedPosition, userId: userId);
  }

  // --------------------------------------------------------------------------
  // Lifecycle Management
  // --------------------------------------------------------------------------

  /// Start automatic background/foreground vicinity tracking for [userId].
  Future<bool> startTracking({
    required String userId,
    bool? isLocationHistoryEnabled,
  }) async {
    _activeUserId = userId;

    if (isLocationHistoryEnabled != null) {
      isLocationHistoryEnabledNotifier.value = isLocationHistoryEnabled;
    }

    if (!isLocationHistoryEnabledNotifier.value) {
      isTrackingNotifier.value = false;
      return false;
    }

    if (mockCheckPermission != null) {
      final allowed = await mockCheckPermission!();
      if (!allowed) {
        isTrackingNotifier.value = false;
        return false;
      }
    } else {
      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          isTrackingNotifier.value = false;
          return false;
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          isTrackingNotifier.value = false;
          return false;
        }
      } catch (_) {
        // Platform or unit test environment exception
      }
    }

    isTrackingNotifier.value = true;

    await _positionSubscription?.cancel();
    final stream = mockPositionStream != null
        ? mockPositionStream!()
        : Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          );

    _positionSubscription = stream.listen(
      (pos) => processPosition(pos, userId: userId),
      onError: (_) {
        // Recover silently on transient GPS disruptions
      },
    );

    // Only invoke explicit mock check in unit test environment
    if (mockGetCurrentPosition != null) {
      try {
        final immediatePos = await mockGetCurrentPosition!();
        await processPosition(immediatePos, userId: userId);
      } catch (_) {}
    }

    return true;
  }

  /// Stop automatic vicinity tracking.
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    isTrackingNotifier.value = false;
  }

  // --------------------------------------------------------------------------
  // Automatic Registered Business Proximity Logging
  // --------------------------------------------------------------------------

  /// Evaluate user [position] against registered businesses.
  /// If in the vicinity (<= 75m) of a registered business, automatically records the visit.
  /// If no registered business is nearby, nothing is recorded.
  Future<bool> processPosition(Position position, {required String userId}) async {
    if (!isLocationHistoryEnabledNotifier.value) {
      return false;
    }
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return false;
    }
    // Concurrency lock: prevent parallel async execution from duplicate GPS pings
    if (_isProcessingPosition) {
      return false;
    }
    _isProcessingPosition = true;

    try {
      _lastPosition = position;

      final businesses = await getRegisteredBusinesses();
      final now = DateTime.now();

      Business? matchedBusiness;
      double minDistance = double.infinity;

      for (final business in businesses) {
        if (business.latitude == null || business.longitude == null) continue;

        final distance = RewardProximity.distanceMeters(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          rewardLatitude: business.latitude!,
          rewardLongitude: business.longitude!,
        );

        if (distance <= vicinityRadiusMeters && distance < minDistance) {
          minDistance = distance;
          matchedBusiness = business;
        }
      }

      if (matchedBusiness != null) {
        // If user is already dwelling at this same business during this visit, do not duplicate
        if (_currentlyDwellingBusinessId == matchedBusiness.id) {
          return false;
        }

        // Check per-business cooldown (prevents rapid re-logging if GPS bounces at boundary)
        final lastTime = _recentVisits[matchedBusiness.id];
        if (lastTime != null && now.difference(lastTime) < visitCooldown) {
          _currentlyDwellingBusinessId = matchedBusiness.id;
          return false;
        }

        // Lock in-memory IMMEDIATELY before awaiting async database operations
        // to prevent any concurrent race condition!
        _currentlyDwellingBusinessId = matchedBusiness.id;
        _recentVisits[matchedBusiness.id] = now;

        final areaName = matchedBusiness.area.isNotEmpty
            ? matchedBusiness.area
            : (matchedBusiness.category.isNotEmpty
                ? matchedBusiness.category
                : 'Penang');

        final recorded = await _userRepository.recordVisit(
          userId: userId,
          name: matchedBusiness.name,
          area: areaName,
          businessId: matchedBusiness.id,
          visitedAt: now,
          latitude: matchedBusiness.latitude,
          longitude: matchedBusiness.longitude,
        );

        if (recorded) {
          lastVisitedBusinessNotifier.value = matchedBusiness.name;
          onBusinessVisitDetected?.call(matchedBusiness);
          return true;
        }
        return false;
      } else {
        // User is not within vicinity of any registered business -> departure detected!
        if (_currentlyDwellingBusinessId != null) {
          _currentlyDwellingBusinessId = null;
        }
      }

      // No registered business nearby -> strictly do not log anything
      return false;
    } finally {
      _isProcessingPosition = false;
    }
  }
}
