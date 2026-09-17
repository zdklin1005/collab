/// Single source of truth for the tourist leveling curve — used by
/// RewardService (which delegates to this instead of keeping its own
/// copy of the formula), MapProgressCard, and the tourist profile
/// screen, so all three always agree on level thresholds and names.
///
/// Five tiers total, calibrated so that completing every daily mission
/// (3/day, using the existing random EXP-per-mission formula in
/// MissionService) reaches max level in roughly a week on an average
/// run. Variance from that formula's randomness means some tourists
/// will hit max level a little earlier or later than exactly 7 days.
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

  int get expToNextLevel => isMaxLevel(level) ? 0 : nextLevelExp - totalExp;

  /// 1.0 at max level (nothing left to fill), rather than dividing by
  /// zero when expRequiredThisLevel is 0.
  double get fraction => expRequiredThisLevel <= 0
      ? 1.0
      : (expIntoLevel / expRequiredThisLevel).clamp(0.0, 1.0);

  String get tierName => tierNameForLevel(level);

  // Cumulative EXP required to *reach* each level, index 0 = level 1.
  // Level 1 requires 0 EXP (everyone starts here). Deltas increase per
  // tier (150, 250, 300, 350) for a natural escalating-effort feel.
  static const List<int> _levelThresholds = [0, 150, 400, 700, 1050];

  static const List<String> tierNames = [
    'New Explorer',
    'Junior Explorer',
    'Seasoned Explorer',
    'Veteran Explorer',
    'Champion Explorer',
  ];

  static int get maxLevel => _levelThresholds.length;

  static bool isMaxLevel(int level) => level >= maxLevel;

  static String tierNameForLevel(int level) {
    final clamped = level.clamp(1, maxLevel);
    return tierNames[clamped - 1];
  }

  /// Cumulative EXP required to reach [level]. Levels beyond [maxLevel]
  /// are clamped to the max-level threshold — there is no further
  /// requirement past Champion Explorer.
  static int expRequiredForLevel(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be at least 1');
    }
    final clamped = level > maxLevel ? maxLevel : level;
    return _levelThresholds[clamped - 1];
  }

  factory ExpProgress.fromTotalExp(int totalExp, [int? currentLevel]) {
    if (totalExp < 0) {
      throw ArgumentError.value(totalExp, 'totalExp', 'must not be negative');
    }

    var level = 1;
    while (level < maxLevel && totalExp >= expRequiredForLevel(level + 1)) {
      level++;
    }

    // Never let the computed level regress below a known stored level.
    if (currentLevel != null && currentLevel > level) {
      level = currentLevel.clamp(1, maxLevel);
    }

    final levelStart = expRequiredForLevel(level);
    final nextLevel = isMaxLevel(level)
        ? levelStart
        : expRequiredForLevel(level + 1);

    return ExpProgress._(
      totalExp: totalExp,
      level: level,
      levelStartExp: levelStart,
      nextLevelExp: nextLevel,
    );
  }
}
