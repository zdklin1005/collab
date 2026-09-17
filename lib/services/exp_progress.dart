/// Single source of truth for the tourist leveling curve — used by
/// RewardService (which delegates to this instead of keeping its own
/// copy of the formula), MapProgressCard, LqTierBadge, and the tourist
/// profile/roadmap screens, so all of them always agree on level
/// thresholds and names.
///
/// 15 tiers total. The curve is a quadratic (10*steps^2 + 10*steps,
/// steps = level-1) chosen so level 15 (max) requires ~2,100 EXP —
/// almost exactly what the earlier 5-level system required for its own
/// max (2,000). Daily mission EXP output (3/day, MissionService's
/// existing random per-mission formula) hasn't changed, so the *pacing*
/// to reach max level is still roughly two weeks of active play — this
/// just spreads the same total distance across three times as many
/// milestones, so level-ups happen more often along the way.
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

  static const int maxLevel = 15;

  static const List<String> tierNames = [
    'New Explorer',
    'Curious Explorer',
    'Junior Explorer',
    'Rising Explorer',
    'Seasoned Explorer',
    'Skilled Explorer',
    'Trailblazing Explorer',
    'Veteran Explorer',
    'Expert Explorer',
    'Master Explorer',
    'Elite Explorer',
    'Renowned Explorer',
    'Legendary Explorer',
    'Mythic Explorer',
    'Champion Explorer',
  ];

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
    final steps = clamped - 1;
    return 10 * steps * steps + 10 * steps;
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