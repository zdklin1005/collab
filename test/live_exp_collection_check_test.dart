import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/screens/interactive_map/live_exp_collection_check.dart';
import 'package:collab/screens/interactive_map/reward_collection_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 10);

  RewardMarker reward({
    int amount = 100,
    double latitude = 5,
    bool active = true,
    DateTime? expiresAt,
    DateTime? availableFrom,
  }) {
    return RewardMarker(
      id: 'exp-slot-1',
      checkpointId: 'landmark:park-1',
      locationType: MapLocationType.landmark,
      locationId: 'park-1',
      type: RewardType.exp,
      title: '100 EXP',
      latitude: latitude,
      longitude: 100,
      expAmount: amount,
      active: active,
      availableFrom: availableFrom ?? now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
    );
  }

  LiveRewardCollectionCheck check({
    RewardMarker? selected,
    List<RewardMarker>? current,
    bool sourceReady = true,
    bool simulation = false,
    bool foreground = true,
    bool permission = true,
    double latitude = 5,
    double accuracy = 5,
    DateTime? recordedAt,
  }) {
    return checkLiveRewardCollection(
      selectedReward: selected ?? reward(),
      currentRewards: current ?? [reward()],
      sourceReady: sourceReady,
      simulationActive: simulation,
      now: now,
      appIsForeground: foreground,
      locationAllowed: permission,
      radiusMeters: 50,
      userLatitude: latitude,
      userLongitude: 100,
      accuracyMeters: accuracy,
      recordedAt: recordedAt ?? now,
    );
  }

  test('matching EXP and reliable nearby GPS pass local checks', () {
    final result = check();

    expect(result.canAttemptClaim, isTrue);
    expect(result.localCheck?.distanceMeters, 0);
  });

  test('simulated movement cannot proceed', () {
    expect(
      check(simulation: true).status,
      LiveRewardCollectionStatus.simulationBlocked,
    );
  });

  test('unavailable source data cannot proceed', () {
    expect(
      check(sourceReady: false).status,
      LiveRewardCollectionStatus.sourceUnavailable,
    );
  });

  test('missing or duplicate reward IDs are rejected', () {
    expect(check(current: []).status, LiveRewardCollectionStatus.rewardChanged);
    expect(
      check(current: [reward(), reward()]).status,
      LiveRewardCollectionStatus.rewardChanged,
    );
  });

  test('changed EXP amount or coordinates are rejected', () {
    expect(
      check(selected: reward(amount: 999)).status,
      LiveRewardCollectionStatus.rewardChanged,
    );
    expect(
      check(selected: reward(latitude: 5.001)).status,
      LiveRewardCollectionStatus.rewardChanged,
    );
  });

  test('equivalent local and UTC availability dates match', () {
    final selected = reward(
      availableFrom: now.subtract(const Duration(hours: 1)).toLocal(),
      expiresAt: now.add(const Duration(hours: 1)).toLocal(),
    );

    expect(check(selected: selected).canAttemptClaim, isTrue);
  });

  test('inactive and expired rewards cannot proceed', () {
    for (final unavailable in [reward(active: false), reward(expiresAt: now)]) {
      final result = check(selected: unavailable, current: [unavailable]);

      expect(result.canAttemptClaim, isFalse);
      expect(result.status, LiveRewardCollectionStatus.rewardChanged);
      expect(result.localCheck, isNull);
    }
  });

  test('background and denied permission cannot proceed', () {
    expect(
      check(foreground: false).localCheck?.status,
      RewardCollectionCheckStatus.appInactive,
    );
    expect(
      check(permission: false).localCheck?.status,
      RewardCollectionCheckStatus.locationAccessRequired,
    );
  });

  test('poor or stale GPS cannot proceed', () {
    expect(
      check(accuracy: 100).localCheck?.status,
      RewardCollectionCheckStatus.locationUnreliable,
    );
    expect(
      check(
        recordedAt: now.subtract(const Duration(minutes: 1)),
      ).localCheck?.status,
      RewardCollectionCheckStatus.locationUnreliable,
    );
  });

  test('out-of-range GPS cannot proceed', () {
    final result = check(latitude: 5.01);

    expect(result.canAttemptClaim, isFalse);
    expect(result.localCheck?.status, RewardCollectionCheckStatus.outOfRange);
  });

  RewardMarker voucher({String offerId = 'offer-1'}) {
    return RewardMarker(
      id: 'voucher-slot-1',
      checkpointId: 'landmark:park-1',
      locationType: MapLocationType.landmark,
      locationId: 'park-1',
      type: RewardType.voucher,
      title: 'Coffee voucher',
      latitude: 5,
      longitude: 100,
      voucherId: offerId,
      availableFrom: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
    );
  }

  test('distant voucher fails with outOfRange', () {
    final marker = voucher();
    final result = check(selected: marker, current: [marker], latitude: 5.01);

    expect(result.canAttemptClaim, isFalse);
    expect(result.localCheck?.status, RewardCollectionCheckStatus.outOfRange);
  });

  test('nearby voucher passes local range checks', () {
    final marker = voucher();
    final result = check(selected: marker, current: [marker]);

    expect(result.canAttemptClaim, isTrue);
    expect(result.localCheck?.distanceMeters, 0);
  });

  test('voucher with poor GPS is blocked', () {
    final marker = voucher();
    final result = check(selected: marker, current: [marker], accuracy: 100);

    expect(result.canAttemptClaim, isFalse);
    expect(
      result.localCheck?.status,
      RewardCollectionCheckStatus.locationUnreliable,
    );
  });

  test('changed voucher offer is rejected', () {
    final result = check(
      selected: voucher(offerId: 'different-offer'),
      current: [voucher()],
    );

    expect(result.status, LiveRewardCollectionStatus.rewardChanged);
  });
}
