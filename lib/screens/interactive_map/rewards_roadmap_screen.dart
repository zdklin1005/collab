import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localquest_theme.dart';
import '../../../core/localquest_widgets.dart';
import '../../../models/localquest_models.dart';
import '../../../services/reward_service.dart';

/// Shows the tourist's current level/EXP progress plus a preview of the
/// next several levels and the voucher each one guarantees. Every level
/// gained awards exactly one voucher (see RewardService.awardExp()'s
/// vouchersAwarded logic) — so this is a preview of a known, guaranteed
/// reward, not a random or varied reward table.
class RewardsRoadmapScreen extends StatelessWidget {
  const RewardsRoadmapScreen({super.key, required this.user});
  final AppUser user;

  static const _previewLevels = 6;

  @override
  Widget build(BuildContext context) {
    final reward = RewardService.instance;
    final numberFormat = NumberFormat('#,##0');

    final currentLevelBaseExp = reward.expRequiredForLevel(user.level);
    final nextLevelExp = reward.expRequiredForLevel(user.level + 1);
    final expIntoLevel = (user.exp - currentLevelBaseExp) < 0
        ? 0
        : user.exp - currentLevelBaseExp;
    final expNeededForLevel = nextLevelExp - currentLevelBaseExp;
    final progress = expNeededForLevel <= 0
        ? 1.0
        : (expIntoLevel / expNeededForLevel).clamp(0.0, 1.0);

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
                          '${user.level}',
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
                              'LEVEL ${user.level}',
                              style: const TextStyle(
                                color: LqColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${numberFormat.format(expIntoLevel)} / '
                              '${numberFormat.format(expNeededForLevel)} EXP '
                              'to level ${user.level + 1}',
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
                      value: progress,
                      minHeight: 10,
                      color: LqColors.primary,
                      backgroundColor: LqColors.line,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('UPCOMING REWARDS', style: monoLabel),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _previewLevels,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final targetLevel = user.level + 1 + index;
                  final expForLevel = reward.expRequiredForLevel(targetLevel);
                  final expRemainingRaw = expForLevel - user.exp;
                  final expRemaining = expRemainingRaw < 0 ? 0 : expRemainingRaw;
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
                            color: isNext ? LqColors.primary : LqColors.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: const Text(
                            '+1 Voucher',
                            style: TextStyle(
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
