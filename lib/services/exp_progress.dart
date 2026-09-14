class ExpProgress {
  const ExpProgress._({
    required this.totalExp,
    required this.level,
    required this.levelStartExp,
    required this.nextLevelExp,
  });

  final int totalExp;
  final int level;

  // Cumulative EXP thresholds.
  final int levelStartExp;
  final int nextLevelExp;

  int get expIntoLevel => totalExp - levelStartExp;
  int get expRequiredThisLevel => nextLevelExp - levelStartExp;
  int get expToNextLevel => nextLevelExp - totalExp;

  double get fraction => expIntoLevel / expRequiredThisLevel;

  // Matches RewardService on origin/temp.
  static int expRequiredForLevel(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be at least 1');
    }

    final steps = level - 1;
    return 100 * steps * steps + 100 * steps;
  }

  factory ExpProgress.fromTotalExp(int totalExp) {
    if (totalExp < 0) {
      throw ArgumentError.value(totalExp, 'totalExp', 'must not be negative');
    }

    var level = 1;
    while (totalExp >= expRequiredForLevel(level + 1)) {
      level++;
    }

    return ExpProgress._(
      totalExp: totalExp,
      level: level,
      levelStartExp: expRequiredForLevel(level),
      nextLevelExp: expRequiredForLevel(level + 1),
    );
  }
}
