import 'package:collab/services/exp_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the existing cumulative level thresholds', () {
    expect(
      List.generate(6, (index) => ExpProgress.expRequiredForLevel(index + 1)),
      [0, 200, 600, 1200, 2000, 3000],
    );
  });

  test('45 EXP gives level 1 with 155 EXP remaining', () {
    final progress = ExpProgress.fromTotalExp(45);

    expect(progress.level, 1);
    expect(progress.totalExp, 45);
    expect(progress.expIntoLevel, 45);
    expect(progress.expRequiredThisLevel, 200);
    expect(progress.expToNextLevel, 155);
    expect(progress.fraction, closeTo(0.225, 0.000001));
  });

  test('level boundaries start the next progress interval', () {
    for (final entry in [
      (0, 1),
      (199, 1),
      (200, 2),
      (599, 2),
      (600, 3),
      (1199, 3),
      (1200, 4),
      (1999, 4),
      (2000, 5),
      (3000, 6),
    ]) {
      final progress = ExpProgress.fromTotalExp(entry.$1);

      expect(progress.level, entry.$2, reason: '${entry.$1} EXP');
      expect(progress.fraction, greaterThanOrEqualTo(0));
      expect(progress.fraction, lessThan(1));
      expect(progress.expToNextLevel, greaterThan(0));
    }

    expect(ExpProgress.fromTotalExp(200).expIntoLevel, 0);
    expect(ExpProgress.fromTotalExp(600).expIntoLevel, 0);
  });

  test('progress uses the current level interval', () {
    final progress = ExpProgress.fromTotalExp(250);

    expect(progress.level, 2);
    expect(progress.levelStartExp, 200);
    expect(progress.nextLevelExp, 600);
    expect(progress.expIntoLevel, 50);
    expect(progress.expRequiredThisLevel, 400);
    expect(progress.expToNextLevel, 350);
    expect(progress.fraction, 0.125);
  });

  test('rejects negative EXP and invalid levels', () {
    expect(() => ExpProgress.fromTotalExp(-1), throwsArgumentError);
    expect(() => ExpProgress.expRequiredForLevel(0), throwsArgumentError);
  });
}
