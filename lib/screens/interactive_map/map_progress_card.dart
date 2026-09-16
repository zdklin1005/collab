import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localquest_theme.dart';
import '../../models/localquest_models.dart';
import '../../services/localquest_services.dart';
import '../../services/reward_service.dart';
import 'rewards_roadmap_screen.dart';

class MapProgressCard extends StatelessWidget {
  const MapProgressCard({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    // Watches the live user doc rather than trusting the snapshot passed
    // in from InteractiveMapScreen, which is only ever set once — without
    // this, the card wouldn't reflect EXP/level changes from missions,
    // check-ins, or reviews until the whole screen rebuilds.
    return StreamBuilder<AppUser>(
      stream: UserRepository.instance.watch(user.id),
      initialData: user,
      builder: (context, snapshot) {
        final liveUser = snapshot.data ?? user;
        final reward = RewardService.instance;
        final numberFormat = NumberFormat('#,##0');

        // Progress WITHIN the current level, using the real EXP curve
        // (RewardService.expRequiredForLevel) rather than a flat total —
        // this used to be a hardcoded 3000 placeholder regardless of
        // level, which became increasingly inaccurate the higher the
        // tourist got (e.g. level 5 actually only needs 2,000 cumulative
        // EXP, level 8 needs 5,600 — a flat target doesn't reflect either).
        final currentLevelBaseExp = reward.expRequiredForLevel(liveUser.level);
        final nextLevelExp = reward.expRequiredForLevel(liveUser.level + 1);
        final expIntoLevel = (liveUser.exp - currentLevelBaseExp) < 0
            ? 0
            : liveUser.exp - currentLevelBaseExp;
        final expNeededForLevel = nextLevelExp - currentLevelBaseExp;
        final progress = expNeededForLevel <= 0
            ? 1.0
            : (expIntoLevel / expNeededForLevel).clamp(0.0, 1.0);

        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RewardsRoadmapScreen(user: liveUser),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
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
                    '${liveUser.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEVEL ${liveUser.level} · EXPLORER',
                        style: const TextStyle(
                          color: LqColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${numberFormat.format(expIntoLevel)} / '
                        '${numberFormat.format(expNeededForLevel)} EXP to next level',
                        style: const TextStyle(
                          color: LqColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: LqColors.primary,
                        backgroundColor: LqColors.line,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: LqColors.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}
