import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../services/check_in_service.dart';

class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({super.key, required this.userId});
  final String userId;

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> {
  bool _checkingIn = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _checkIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final result = await CheckInService.instance.checkIn(widget.userId);
      if (!mounted) return;
      final message = result.alreadyCheckedInToday
          ? "You've already checked in today — come back tomorrow!"
          : 'Checked in! +${result.expAwarded} EXP'
              '${result.levelUpResult != null ? ' — Level up!' : ''}'
              ' · ${result.streakCount}-day streak';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check in. Check your connection and try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> _userStream(String uid) {
    try {
      return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LqPage(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            stream: _userStream(widget.userId),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final streakCount = (data['streakCount'] as num?)?.toInt() ?? 0;
              final lastCheckIn = (data['lastCheckInDate'] as Timestamp?)?.toDate();
              final alreadyCheckedInToday =
                  lastCheckIn != null && _isSameDay(lastCheckIn, DateTime.now());
              final expReward = CheckInService.instance.dailyExpReward(
                alreadyCheckedInToday ? streakCount : streakCount + 1,
              );

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LqBackButton(label: 'Profile'),
                    const SizedBox(height: 8),
                    const Text(
                      'Daily check-in',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: LqColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Check in daily to build your streak and earn bonus EXP!',
                      style: TextStyle(color: LqColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Main Streak Card
                    LqCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: const BoxDecoration(
                                  color: LqColors.peachSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.local_fire_department,
                                  color: Colors.deepOrange,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      streakCount > 0
                                          ? '$streakCount Day Streak!'
                                          : 'Start Your Streak',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        color: LqColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      alreadyCheckedInToday
                                          ? "You're all set for today! Come back tomorrow."
                                          : "Earn +$expReward EXP today by checking in.",
                                      style: const TextStyle(
                                        color: LqColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const LqDashedDivider(),
                          const SizedBox(height: 16),

                          // 7-day streak preview
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (index) {
                              final dayNum = index + 1;
                              final normalizedStreak = streakCount % 7 == 0 && streakCount > 0 ? 7 : streakCount % 7;
                              final isPassedOrCurrent = dayNum <= normalizedStreak;

                              return Column(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPassedOrCurrent
                                          ? (alreadyCheckedInToday || dayNum < normalizedStreak
                                              ? const Color(0xFFFFECE0)
                                              : LqColors.primarySoft)
                                          : const Color(0xFFF0F2F5),
                                      border: Border.all(
                                        color: isPassedOrCurrent
                                            ? Colors.deepOrange
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: isPassedOrCurrent
                                          ? const Icon(
                                              Icons.check,
                                              size: 20,
                                              color: Colors.deepOrange,
                                            )
                                          : Text(
                                              '+${20 + index * 5}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: LqColors.muted,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'D$dayNum',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isPassedOrCurrent ? FontWeight.w700 : FontWeight.w500,
                                      color: isPassedOrCurrent ? Colors.deepOrange : LqColors.muted,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Check In Button
                          if (alreadyCheckedInToday)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: LqColors.success, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Checked In Today',
                                    style: TextStyle(
                                      color: LqColors.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            LqButton(
                              label: _checkingIn ? 'Checking In…' : 'Check In Now (+$expReward EXP)',
                              onPressed: _checkingIn ? null : _checkIn,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('STREAK REWARDS', style: monoLabel),
                    const SizedBox(height: 10),
                    LqCard(
                      child: Column(
                        children: [
                          _RewardInfoRow(
                            icon: Icons.bolt,
                            title: 'Base Reward',
                            detail: '+20 EXP for checking in',
                          ),
                          const Divider(height: 16),
                          _RewardInfoRow(
                            icon: Icons.trending_up,
                            title: 'Streak Multiplier',
                            detail: '+5 bonus EXP per streak day (up to +50 EXP)',
                          ),
                          const Divider(height: 16),
                          _RewardInfoRow(
                            icon: Icons.military_tech_outlined,
                            title: 'Milestone Rewards',
                            detail: 'Maintain long streaks to earn achievement badges',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RewardInfoRow extends StatelessWidget {
  const _RewardInfoRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: LqColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LqColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(
                detail,
                style: const TextStyle(color: LqColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
