import 'package:collab/services/reward_proximity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double distance(double lat1, double lng1, double lat2, double lng2) =>
      RewardProximity.distanceMeters(
        userLatitude: lat1,
        userLongitude: lng1,
        rewardLatitude: lat2,
        rewardLongitude: lng2,
      );

  test('identical coordinates have zero distance', () {
    expect(distance(5, 100, 5, 100), 0);
  });

  test('one degree at the equator is approximately 111.195 km', () {
    expect(distance(0, 0, 0, 1), closeTo(111195, 1));
  });

  test('distance is symmetric', () {
    expect(
      distance(5, 100, 5.001, 100.001),
      closeTo(distance(5.001, 100.001, 5, 100), 0.000001),
    );
  });

  test('antimeridian uses the short distance', () {
    expect(distance(0, 179.999, 0, -179.999), closeTo(222.39, 0.1));
  });

  test('antipodal distance remains finite', () {
    expect(distance(0, 0, 0, 180), closeTo(20015087, 1));
  });

  test('radius includes the exact boundary without rounding', () {
    expect(
      RewardProximity.isWithinRadius(distanceMeters: 49.999, radiusMeters: 50),
      isTrue,
    );
    expect(
      RewardProximity.isWithinRadius(distanceMeters: 50, radiusMeters: 50),
      isTrue,
    );
    expect(
      RewardProximity.isWithinRadius(distanceMeters: 50.001, radiusMeters: 50),
      isFalse,
    );
  });

  test('radius is configurable rather than fixed at 50 metres', () {
    expect(
      RewardProximity.isWithinRadius(distanceMeters: 20, radiusMeters: 5),
      isFalse,
    );
    expect(
      RewardProximity.isWithinRadius(distanceMeters: 20, radiusMeters: 25),
      isTrue,
    );
    expect(
      RewardProximity.isWithinRadius(distanceMeters: 0, radiusMeters: 5),
      isTrue,
    );
  });

  test('invalid coordinates are rejected for both endpoints', () {
    for (final latitude in [90.1, -90.1, double.nan, double.infinity]) {
      expect(() => distance(latitude, 0, 0, 0), throwsArgumentError);
      expect(() => distance(0, 0, latitude, 0), throwsArgumentError);
    }
    for (final longitude in [
      180.1,
      -180.1,
      double.nan,
      double.negativeInfinity,
    ]) {
      expect(() => distance(0, longitude, 0, 0), throwsArgumentError);
      expect(() => distance(0, 0, 0, longitude), throwsArgumentError);
    }
  });

  test('invalid distances and radii are rejected', () {
    for (final value in [-1.0, double.nan, double.infinity]) {
      expect(
        () => RewardProximity.isWithinRadius(
          distanceMeters: value,
          radiusMeters: 50,
        ),
        throwsArgumentError,
      );
    }
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => RewardProximity.isWithinRadius(
          distanceMeters: 10,
          radiusMeters: value,
        ),
        throwsArgumentError,
      );
    }
  });
}
