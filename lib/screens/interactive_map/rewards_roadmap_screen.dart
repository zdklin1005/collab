import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localquest_theme.dart';
import '../../../core/localquest_widgets.dart';
import '../../../models/localquest_models.dart';
import '../../../services/exp_progress.dart';

/// Shows the tourist's current level/EXP progress plus a preview of the
/// remaining levels up to Champion Explorer (level 5, the max). Derives
/// level from EXP via ExpProgress rather than trusting the passed-in
/// user.level field directly, so this always agrees with the map card
/// and profile screen even if the caller's user object is a step stale.
class RewardsRoadmapScreen extends StatelessWidget {
  const RewardsRoadmapScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final progress = ExpProgress.fromTotalExp(
      user.exp < 0 ? 0 : user.exp,
      user.level,
    );
    final numberFormat = NumberFormat('#,##0');
    final isMaxLevel = ExpProgress.isMaxLevel(progress.level);
    final remainingLevels = ExpProgress.maxLevel - progress.level;

    return LqPage(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LqBackButton(label: 'Discover'),
            const SizedBox(height: 8),
            const Text(
              'Your progress',
              style: TextStyle(
                fontSize: 32,
                height: 1.12,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: LqColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            LqCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: LqColors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '${progress.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL ${progress.level} · ${progress.tierName.toUpperCase()}',
                              style: const TextStyle(
                                color: LqColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMaxLevel
                                  ? 'Max level reached'
                                  : '${numberFormat.format(progress.expIntoLevel)} / '
                                  '${numberFormat.format(progress.expRequiredThisLevel)} EXP '
                                  'to level ${progress.level + 1}',
                              style: const TextStyle(
                                color: LqColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 10,
                      color: LqColors.primary,
                      backgroundColor: LqColors.line,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('UPCOMING TIERS', style: monoLabel),
            const SizedBox(height: 12),
            Expanded(
              child: isMaxLevel
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: LqColors.primary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "You've reached Champion Explorer",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: LqColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "There's no higher tier — you've maxed out the leveling system.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: LqColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.separated(
                itemCount: remainingLevels,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final targetLevel = progress.level + 1 + index;
                  final expForLevel = ExpProgress.expRequiredForLevel(
                    targetLevel,
                  );
                  final expRemainingRaw = expForLevel - progress.totalExp;
                  final expRemaining = expRemainingRaw < 0
                      ? 0
                      : expRemainingRaw;
                  final isNext = index == 0;

                  return LqCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isNext
                                ? LqColors.primarySoft
                                : const Color(0xFFF0F4FC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.lock_outline,
                            color: isNext
                                ? LqColors.primary
                                : LqColors.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level $targetLevel',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isNext
                                    ? '${numberFormat.format(expRemaining)} EXP to go'
                                    : '${numberFormat.format(expForLevel)} total EXP',
                                style: const TextStyle(
                                  color: LqColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBE0C4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ExpProgress.tierNameForLevel(targetLevel),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: Color(0xFF8A5A22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}