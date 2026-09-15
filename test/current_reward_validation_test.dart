import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/current_reward_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 14, 16);
  final now = start.add(const Duration(hours: 10));

  RewardMarker marker({
    int exp = 100,
    double latitude = 5,
    bool active = true,
    RewardType type = RewardType.exp,
    String voucherId = 'offer-1',
    bool localTime = false,
  }) {
    final end = start.add(const Duration(days: 1));

    return RewardMarker(
      id: 'reward-1',
      checkpointId: 'landmark:park',
      locationType: MapLocationType.landmark,
      locationId: 'park',
      type: type,
      title: 'Reward',
      latitude: latitude,
      longitude: 100,
      expAmount: type == RewardType.exp ? exp : 0,
      voucherId: type == RewardType.voucher ? voucherId : null,
      availableFrom: localTime ? start.toLocal() : start,
      expiresAt: localTime ? end.toLocal() : end,
      active: active,
    );
  }

  RewardMarker? validate(
    RewardMarker selected,
    List<RewardMarker> current, {
    DateTime? at,
  }) {
    return findMatchingCurrentReward(
      selected: selected,
      currentRewards: current,
      now: at ?? now,
    );
  }

  test('returns the current matching reward', () {
    final selected = marker();
    final current = marker();

    expect(validate(selected, [current]), same(current));
  });

  test('rejects missing and duplicate reward IDs', () {
    expect(validate(marker(), []), isNull);
    expect(validate(marker(), [marker(), marker()]), isNull);
  });

  test('rejects changed EXP amount', () {
    expect(validate(marker(), [marker(exp: 200)]), isNull);
  });

  test('rejects changed marker coordinates', () {
    expect(validate(marker(), [marker(latitude: 5.001)]), isNull);
  });

  test('rejects inactive rewards', () {
    expect(validate(marker(active: false), [marker(active: false)]), isNull);
  });

  test('rejects rewards at their exact expiry', () {
    expect(
      validate(marker(), [marker()], at: start.add(const Duration(days: 1))),
      isNull,
    );
  });

  test('rejects rewards before availability begins', () {
    expect(
      validate(marker(), [
        marker(),
      ], at: start.subtract(const Duration(seconds: 1))),
      isNull,
    );
  });

  test('accepts equivalent UTC and local timestamps', () {
    expect(validate(marker(), [marker(localTime: true)]), isNotNull);
  });

  test('rejects a changed voucher offer', () {
    expect(
      validate(marker(type: RewardType.voucher), [
        marker(type: RewardType.voucher, voucherId: 'offer-2'),
      ]),
      isNull,
    );
  });
}
