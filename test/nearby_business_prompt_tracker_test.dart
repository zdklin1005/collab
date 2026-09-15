import 'package:collab/models/localquest_models.dart';
import 'package:collab/services/nearby_business_detector.dart';
import 'package:collab/services/nearby_business_prompt_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NearbyBusiness candidate(String id, double distance) {
    return NearbyBusiness(
      business: Business(
        id: id,
        ownerId: 'merchant-a',
        name: 'Demo $id',
        category: 'Food & Beverage',
        address: 'Test location',
        phone: '',
        latitude: 5,
        longitude: 100,
      ),
      distanceMeters: distance,
    );
  }

  final cafe = candidate('cafe', 10);
  final shop = candidate('shop', 20);

  test('selects nearest unshown business without consuming it', () {
    final tracker = NearbyBusinessPromptTracker();

    for (var attempt = 0; attempt < 3; attempt++) {
      expect(
        tracker
            .nextCandidate(touristId: 'tourist-a', nearby: [cafe, shop])
            ?.business
            .id,
        'cafe',
      );
    }
  });

  test('shown business is skipped and repeated marking returns false', () {
    final tracker = NearbyBusinessPromptTracker();

    expect(
      tracker.markShown(touristId: 'tourist-a', businessId: 'cafe'),
      isTrue,
    );
    expect(
      tracker.markShown(touristId: 'tourist-a', businessId: 'cafe'),
      isFalse,
    );

    expect(
      tracker
          .nextCandidate(touristId: 'tourist-a', nearby: [cafe, shop])
          ?.business
          .id,
      'shop',
    );
  });

  test('leaving and returning does not reset reminder history', () {
    final tracker = NearbyBusinessPromptTracker();

    tracker.markShown(touristId: 'tourist-a', businessId: 'cafe');

    expect(tracker.nextCandidate(touristId: 'tourist-a', nearby: []), isNull);
    expect(
      tracker.nextCandidate(touristId: 'tourist-a', nearby: [cafe]),
      isNull,
    );
  });

  test('another tourist has independent reminder history', () {
    final tracker = NearbyBusinessPromptTracker();

    tracker.markShown(touristId: 'tourist-a', businessId: 'cafe');

    expect(
      tracker
          .nextCandidate(touristId: 'tourist-b', nearby: [cafe])
          ?.business
          .id,
      'cafe',
    );
  });

  test('no candidate remains after all businesses were shown', () {
    final tracker = NearbyBusinessPromptTracker();

    for (final id in ['cafe', 'shop']) {
      tracker.markShown(touristId: 'tourist-a', businessId: id);
    }

    expect(
      tracker.nextCandidate(touristId: 'tourist-a', nearby: [cafe, shop]),
      isNull,
    );
  });

  test('a new tracker starts a new reminder session', () {
    final first = NearbyBusinessPromptTracker();
    first.markShown(touristId: 'tourist-a', businessId: 'cafe');

    expect(
      NearbyBusinessPromptTracker()
          .nextCandidate(touristId: 'tourist-a', nearby: [cafe])
          ?.business
          .id,
      'cafe',
    );
  });

  test('empty account or business IDs are rejected', () {
    final tracker = NearbyBusinessPromptTracker();

    expect(
      () => tracker.nextCandidate(touristId: ' ', nearby: [cafe]),
      throwsArgumentError,
    );
    expect(
      () => tracker.markShown(touristId: 'tourist-a', businessId: ''),
      throwsArgumentError,
    );
  });
}
