import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/screens/interactive_map/location_quality.dart';
import 'package:collab/screens/interactive_map/reward_collection_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/services/demo_map_claim_store.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 2);

  RewardMarker makeReward({
    bool active = true,
    DateTime? availableFrom,
    DateTime? expiresAt,
    RewardType type = RewardType.exp,
  }) {
    return RewardMarker(
      id: 'test-spawn',
      checkpointId: 'test-checkpoint',
      locationType: MapLocationType.business,
      locationId: 'test-business',
      type: type,
      title: 'Demo reward',
      latitude: 5,
      longitude: 100,
      expAmount: type == RewardType.exp ? 100 : 0,
      voucherId: type == RewardType.voucher ? 'test-offer' : null,
      availableFrom: availableFrom ?? now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
      active: active,
    );
  }

  RewardCollectionCheck check({
    RewardMarker? reward,
    DateTime? checkedAt,
    bool foreground = true,
    bool allowed = true,
    bool hasPosition = true,
    double latitude = 5,
    double longitude = 100,
    double? accuracy = 5,
    DateTime? recordedAt,
    double radius = 50,
  }) {
    return checkRewardCollection(
      reward: reward ?? makeReward(),
      now: checkedAt ?? now,
      appIsForeground: foreground,
      locationAllowed: allowed,
      radiusMeters: radius,
      userLatitude: hasPosition ? latitude : null,
      userLongitude: hasPosition ? longitude : null,
      accuracyMeters: accuracy,
      recordedAt: hasPosition ? recordedAt ?? now : null,
    );
  }

  test('valid EXP and voucher pass local prechecks', () {
    for (final type in RewardType.values) {
      final result = check(reward: makeReward(type: type));

      expect(result.canProceedToDemo, isTrue);
      expect(result.distanceMeters, 0);
    }
  });

  test('background app cannot proceed', () {
    expect(
      check(foreground: false).status,
      RewardCollectionCheckStatus.appInactive,
    );
  });

  test('inactive, expired and future rewards cannot proceed', () {
    for (final reward in [
      makeReward(active: false),
      makeReward(expiresAt: now),
      makeReward(availableFrom: now.add(const Duration(minutes: 1))),
    ]) {
      expect(
        check(reward: reward).status,
        RewardCollectionCheckStatus.rewardUnavailable,
      );
    }
  });

  test('missing access or position cannot proceed', () {
    expect(
      check(allowed: false).status,
      RewardCollectionCheckStatus.locationAccessRequired,
    );

    expect(
      check(hasPosition: false).status,
      RewardCollectionCheckStatus.locationUnavailable,
    );
  });

  test('poor and unknown accuracy cannot proceed', () {
    expect(check(accuracy: 60).locationQuality, LocationQuality.inaccurate);

    for (final accuracy in <double?>[
      null,
      0,
      -1,
      double.nan,
      double.infinity,
    ]) {
      final result = check(accuracy: accuracy);

      expect(result.canProceedToDemo, isFalse);
      expect(result.locationQuality, LocationQuality.unknownAccuracy);
    }
  });

  test('stale and implausibly future readings cannot proceed', () {
    for (final timestamp in [
      now.subtract(const Duration(seconds: 31)),
      now.add(const Duration(seconds: 6)),
    ]) {
      final result = check(recordedAt: timestamp);

      expect(result.canProceedToDemo, isFalse);
      expect(result.locationQuality, LocationQuality.stale);
    }
  });

  test('invalid user coordinates cannot proceed', () {
    final result = check(latitude: double.nan);

    expect(result.status, RewardCollectionCheckStatus.invalidCoordinates);
    expect(result.canProceedToDemo, isFalse);
  });

  test('distant position reports out of range', () {
    final result = check(latitude: 5.001);

    expect(result.status, RewardCollectionCheckStatus.outOfRange);
    expect(result.distanceMeters, greaterThan(50));
    expect(result.canProceedToDemo, isFalse);
  });

  test('moving away after preview fails the new check', () {
    final reward = makeReward();

    expect(check(reward: reward).canProceedToDemo, isTrue);

    final later = now.add(const Duration(seconds: 10));
    final result = check(
      reward: reward,
      checkedAt: later,
      recordedAt: later,
      latitude: 5.001,
    );

    expect(result.status, RewardCollectionCheckStatus.outOfRange);
  });

  for (final type in RewardType.values) {
    test('${type.name}: expiry after preview prevents a claim', () {
      final expiry = now.add(const Duration(seconds: 10));
      final reward = makeReward(type: type, expiresAt: expiry);
      final store = DemoMapClaimStore();

      // The reward is eligible when the preview opens.
      final previewCheck = check(
        reward: reward,
        checkedAt: now,
        recordedAt: now,
      );

      expect(previewCheck.canProceedToDemo, isTrue);

      // It remains eligible immediately before expiry.
      final justBefore = expiry.subtract(const Duration(microseconds: 1));

      expect(
        check(
          reward: reward,
          checkedAt: justBefore,
          recordedAt: justBefore,
        ).canProceedToDemo,
        isTrue,
      );

      // At expiry and afterward, a fresh collection check rejects it.
      for (final attemptedAt in [
        expiry,
        expiry.add(const Duration(seconds: 1)),
      ]) {
        final collectionCheck = check(
          reward: reward,
          checkedAt: attemptedAt,
          recordedAt: attemptedAt,
        );

        expect(
          collectionCheck.status,
          RewardCollectionCheckStatus.rewardUnavailable,
        );
        expect(collectionCheck.canProceedToDemo, isFalse);

        // The store independently rejects the expired reward too,
        // even if a caller mistakenly tries to record it.
        expect(
          store.recordDemoClaim(
            touristId: 'tourist-a',
            reward: reward,
            now: attemptedAt,
          ),
          DemoMapClaimStatus.rewardUnavailable,
        );

        expect(store.claimsFor('tourist-a'), isEmpty);
        expect(
          store.nextEligibleAt(
            touristId: 'tourist-a',
            checkpointId: reward.checkpointId,
          ),
          isNull,
        );
      }
    });
  }

  test('permission loss after preview fails the new check', () {
    expect(check().canProceedToDemo, isTrue);

    expect(
      check(allowed: false).status,
      RewardCollectionCheckStatus.locationAccessRequired,
    );
  });

  test('invalid radius is rejected', () {
    for (final radius in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => check(radius: radius), throwsArgumentError);
    }
  });
}
