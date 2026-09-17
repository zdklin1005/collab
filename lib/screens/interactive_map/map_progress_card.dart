import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localquest_theme.dart';
import '../../models/localquest_models.dart';
import '../../services/exp_progress.dart';
import '../../services/localquest_services.dart';
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
        final progress = ExpProgress.fromTotalExp(
          liveUser.exp < 0 ? 0 : liveUser.exp,
          liveUser.level,
        );
        final numberFormat = NumberFormat('#,##0');

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
                    '${progress.level}',
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
                        'LEVEL ${progress.level} · ${progress.tierName.toUpperCase()}',
                        style: const TextStyle(
                          color: LqColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${numberFormat.format(progress.expIntoLevel)} / '
                        '${numberFormat.format(progress.expRequiredThisLevel)} EXP to next level',
                        style: const TextStyle(
                          color: LqColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.fraction,
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