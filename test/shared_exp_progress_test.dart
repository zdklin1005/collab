import 'package:collab/services/exp_progress.dart';
import 'package:collab/services/reward_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = RewardService.instance;

  test('shared level thresholds match the agreed curve', () {
    const thresholds = [0, 200, 600, 1200, 2000, 3000];

    for (var index = 0; index < thresholds.length; index++) {
      expect(service.expRequiredForLevel(index + 1), thresholds[index]);
    }
  });

  test('reward service and map agree around level boundaries', () {
    for (final total in [
      0,
      45,
      199,
      200,
      201,
      599,
      600,
      1199,
      1200,
      2000,
      2550,
      3000,
    ]) {
      final progress = ExpProgress.fromTotalExp(total);

      expect(service.levelForExp(total), progress.level);
      expect(service.expToNextLevel(total), progress.expToNextLevel);
    }
  });

  test('existing RewardService fallback behaviour is preserved', () {
    expect(service.expRequiredForLevel(0), 0);
    expect(service.expRequiredForLevel(-5), 0);
    expect(service.levelForExp(-10), 1);
    expect(service.expToNextLevel(-10), 210);
  });
}
