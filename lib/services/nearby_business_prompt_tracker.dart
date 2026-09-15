import 'nearby_business_detector.dart';

/// Session-only reminder history, not reward-claim history.
///
/// Keep one shared instance across recreated Discover screens.
/// Different tourist accounts have independent reminder histories.
class NearbyBusinessPromptTracker {
  final Map<String, Set<String>> _shownByTourist = {};

  /// Returns the first unshown candidate.
  ///
  /// Supply the nearest-first results from findNearbyBusinesses,
  /// after checking current location quality and foreground state.
  /// Selecting a candidate does not mark it as shown.
  NearbyBusiness? nextCandidate({
    required String touristId,
    required Iterable<NearbyBusiness> nearby,
  }) {
    _validateId(touristId);

    final shown = _shownByTourist[touristId];

    for (final candidate in nearby) {
      final business = candidate.business;

      if (!business.active ||
          business.id.trim().isEmpty ||
          business.name.trim().isEmpty ||
          !candidate.distanceMeters.isFinite ||
          candidate.distanceMeters < 0) {
        continue;
      }

      if (shown?.contains(business.id) ?? false) continue;

      return candidate;
    }

    return null;
  }

  /// Call when the UI actually presents the reminder,
  /// not merely when a business is detected.
  ///
  /// Returns false if this tourist already saw that business.
  bool markShown({required String touristId, required String businessId}) {
    _validateId(touristId);
    _validateId(businessId);

    return _shownByTourist
        .putIfAbsent(touristId, () => <String>{})
        .add(businessId);
  }

  static void _validateId(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'id', 'Must not be empty.');
    }
  }
}
