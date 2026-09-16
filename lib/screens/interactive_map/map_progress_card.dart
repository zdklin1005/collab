import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localquest_theme.dart';
import '../../models/localquest_models.dart';

import '../../services/exp_progress.dart';

class MapProgressCard extends StatelessWidget {
  const MapProgressCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final progress = ExpProgress.fromTotalExp(user.exp < 0 ? 0 : user.exp);
    final numberFormat = NumberFormat('#,##0');

    return Container(
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
                  'LEVEL ${progress.level} · EXPLORER',
                  style: const TextStyle(
                    color: LqColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${numberFormat.format(progress.expIntoLevel)} / '
                  '${numberFormat.format(progress.expRequiredThisLevel)} EXP',
                  style: const TextStyle(
                    color: LqColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.fraction,
                  semanticsLabel: 'Progress to level ${progress.level + 1}',
                  semanticsValue:
                      '${progress.expToNextLevel} EXP remaining; '
                      '${progress.totalExp} total EXP',
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: LqColors.primary,
                  backgroundColor: LqColors.line,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
