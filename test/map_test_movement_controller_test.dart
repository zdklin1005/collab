import 'package:collab/services/map_test_movement_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Generic test coordinates, not a private location.
  final start = LatLng(5, 100);

  test('starts at the configured position', () {
    final controller = MapTestMovementController(start: start);

    expect(controller.point.latitude, 5);
    expect(controller.point.longitude, 100);
    expect(controller.stepMeters, 10);
  });

  test('each direction moves the expected coordinate', () {
    for (final direction in TestMoveDirection.values) {
      final controller = MapTestMovementController(start: start);
      final moved = controller.move(direction);

      switch (direction) {
        case TestMoveDirection.north:
          expect(moved.latitude, greaterThan(start.latitude));
          expect(moved.longitude, closeTo(start.longitude, 0.000001));
        case TestMoveDirection.south:
          expect(moved.latitude, lessThan(start.latitude));
          expect(moved.longitude, closeTo(start.longitude, 0.000001));
        case TestMoveDirection.east:
          expect(moved.longitude, greaterThan(start.longitude));
          expect(moved.latitude, closeTo(start.latitude, 0.000001));
        case TestMoveDirection.west:
          expect(moved.longitude, lessThan(start.longitude));
          expect(moved.latitude, closeTo(start.latitude, 0.000001));
      }
    }
  });

  test('one northward step is approximately 10 metres', () {
    final controller = MapTestMovementController(start: start);
    final moved = controller.move(TestMoveDirection.north);

    expect(
      moved.latitude - start.latitude,
      closeTo(0.000089932, 0.00000001),
    );
  });

  test('repeated steps accumulate and reset restores the start', () {
    final controller = MapTestMovementController(start: start);

    controller.move(TestMoveDirection.north);
    final moved = controller.move(TestMoveDirection.north);

    expect(
      moved.latitude - start.latitude,
      closeTo(0.000179864, 0.00000002),
    );

    final reset = controller.reset();
    expect(reset.latitude, start.latitude);
    expect(reset.longitude, start.longitude);
  });

  test('rejects invalid step sizes', () {
    for (final step in [0.0, -10.0, 101.0, double.nan, double.infinity]) {
      expect(
        () => MapTestMovementController(
          start: start,
          stepMeters: step,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects a start outside the supported test area', () {
    expect(
      () => MapTestMovementController(start: LatLng(89, 100)),
      throwsArgumentError,
    );
  });

  test('a rejected movement preserves the previous position', () {
    final controller = MapTestMovementController(
      start: LatLng(88.99999, 100),
    );

    expect(
      () => controller.move(TestMoveDirection.north),
      throwsArgumentError,
    );

    expect(controller.point.latitude, 88.99999);
    expect(controller.point.longitude, 100);
  });
}