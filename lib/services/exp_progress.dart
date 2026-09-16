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

  double get fraction =>
      expRequiredThisLevel > 0 ? (expIntoLevel / expRequiredThisLevel).clamp(0.0, 1.0) : 1.0;

  // Shared cumulative EXP curve for map progress and RewardService.
  static int expRequiredForLevel(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be at least 1');
    }

    final steps = level - 1;
    return 100 * steps * steps + 100 * steps;
  }

  factory ExpProgress.fromTotalExp(int totalExp, [int? currentLevel]) {
    if (totalExp < 0) {
      throw ArgumentError.value(totalExp, 'totalExp', 'must not be negative');
    }

    var calculatedLevel = 1;
    while (totalExp >= expRequiredForLevel(calculatedLevel + 1)) {
      calculatedLevel++;
    }

    final level = (currentLevel != null && currentLevel > 0)
        ? currentLevel
        : calculatedLevel;

    return ExpProgress._(
      totalExp: totalExp,
      level: level,
      levelStartExp: expRequiredForLevel(level),
      nextLevelExp: expRequiredForLevel(level + 1),
    );
  }
}
