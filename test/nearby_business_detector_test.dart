import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/nearby_business_detector.dart';
import 'package:collab/services/reward_proximity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business({
    String id = 'business-a',
    bool active = true,
    double? latitude = 5,
    double? longitude = 100,
  }) {
    return Business(
      id: id,
      ownerId: 'merchant-a',
      name: 'Demo business',
      category: 'Food & Beverage',
      address: 'Test location',
      phone: '',
      active: active,
      latitude: latitude,
      longitude: longitude,
    );
  }

  List<NearbyBusiness> detect(
    List<Business> businesses, {
    double radius = 100,
  }) {
    return findNearbyBusinesses(
      businesses: businesses,
      userLatitude: 5,
      userLongitude: 100,
      radiusMeters: radius,
    );
  }

  test('includes nearby active businesses and sorts nearest first', () {
    final results = detect([
      business(id: 'farther', latitude: 5.0005),
      business(id: 'nearest'),
      business(id: 'outside', latitude: 5.01),
      business(id: 'inactive', active: false),
    ]);

    expect(results.map((item) => item.business.id).toList(), [
      'nearest',
      'farther',
    ]);
    expect(results.first.distanceMeters, 0);
    expect(results.last.distanceMeters, greaterThan(0));
    expect(results.last.distanceMeters, lessThan(100));
  });

  test('includes the exact radius boundary', () {
    final distance = RewardProximity.distanceMeters(
      userLatitude: 5,
      userLongitude: 100,
      rewardLatitude: 5.0005,
      rewardLongitude: 100,
    );

    final candidate = business(latitude: 5.0005);

    expect(detect([candidate], radius: distance), hasLength(1));
    expect(detect([candidate], radius: distance - 0.001), isEmpty);
  });

  test('skips missing and invalid business coordinates', () {
    final results = detect([
      business(id: 'missing', latitude: null),
      business(id: 'invalid', latitude: 91),
      business(id: 'not-finite', longitude: double.nan),
      business(id: 'valid'),
    ]);

    expect(results.single.business.id, 'valid');
  });

  test('duplicate records appear only once', () {
    final candidate = business();

    expect(detect([candidate, candidate]), hasLength(1));
  });

  test('equal distances use business ID for stable ordering', () {
    final results = detect([
      business(id: 'business-b'),
      business(id: 'business-a'),
    ]);

    expect(results.map((item) => item.business.id).toList(), [
      'business-a',
      'business-b',
    ]);
  });

  test('empty input returns empty results', () {
    expect(detect([]), isEmpty);
  });

  test('invalid radius is rejected even for empty input', () {
    for (final radius in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => detect([], radius: radius), throwsArgumentError);
    }
  });

  test('invalid user coordinates are rejected', () {
    expect(
      () => findNearbyBusinesses(
        businesses: [],
        userLatitude: double.nan,
        userLongitude: 100,
        radiusMeters: 100,
      ),
      throwsArgumentError,
    );
  });

  test('results cannot be modified externally', () {
    final results = detect([business()]);

    expect(() => results.clear(), throwsUnsupportedError);
  });
}
