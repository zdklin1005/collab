import 'package:collab/models/localquest_models.dart';
import 'package:collab/models/map_location.dart';
import 'package:collab/services/landmark_parser.dart';
import 'package:collab/services/place_checkpoint_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business({bool approved = false}) {
    return Business(
      id: 'business-test',
      ownerId: 'merchant-test',
      name: 'Test business',
      category: 'Cafe',
      address: 'Test address',
      phone: '',
      latitude: 5,
      longitude: 100,
      rewardPlacementApproved: approved,
    );
  }

  Map<String, dynamic> landmarkData() => {
    'title': 'Test park',
    'category': 'Park & Garden',
    'address': 'Test address',
    'latitude': 5.0,
    'longitude': 100.0,
    'active': true,
  };

  test('unapproved business stays visible without a checkpoint', () {
    final location = MapLocation.fromBusiness(business())!;

    expect(location.canDisplay, isTrue);
    expect(location.rewardPlacementApproved, isFalse);
    expect(derivePlaceCheckpoints([location]), isEmpty);
  });

  test('approved business can produce a checkpoint', () {
    final location = MapLocation.fromBusiness(business(approved: true))!;

    expect(location.rewardPlacementApproved, isTrue);
    expect(
      derivePlaceCheckpoints([location]).single.id,
      'business:business-test',
    );
  });

  test('landmark requires boolean true for approval', () {
    for (final value in <Object?>[null, false, 'true', 1, true]) {
      final data = landmarkData()..['rewardPlacementApproved'] = value;

      final location = parseLandmark('park-test', data)!;

      expect(location.canDisplay, isTrue);
      expect(location.rewardPlacementApproved, value == true);
      expect(derivePlaceCheckpoints([location]).length, value == true ? 1 : 0);
    }
  });

  test('missing landmark approval defaults to false', () {
    final location = parseLandmark('park-test', landmarkData())!;

    expect(location.canDisplay, isTrue);
    expect(location.rewardPlacementApproved, isFalse);
    expect(derivePlaceCheckpoints([location]), isEmpty);
  });
}
