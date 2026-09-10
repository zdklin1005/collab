import 'package:cloud_firestore/cloud_firestore.dart';

import 'reward_service.dart';

/// Result of a daily check-in attempt.
class CheckInResult {
  const CheckInResult({
    required this.alreadyCheckedInToday,
    required this.streakCount,
    required this.expAwarded,
    this.levelUpResult,
  });

  final bool alreadyCheckedInToday;
  final int streakCount;
  final int expAwarded;

  /// Non-null only when this check-in also caused a level-up.
  final ExpAwardResult? levelUpResult;
}

/// Handles daily check-in streaks.
///
/// Deliberately does NOT modify [AppUser] in localquest_models.dart —
/// `streakCount` and `lastCheckInDate` are stored as plain extra fields
/// directly on the same `users/{uid}` Firestore document instead. This
/// keeps the shared user model untouched (avoiding merge conflicts with
/// whoever owns that file) while still living on the same document, so
/// there's nothing extra to fetch elsewhere. Read via the raw document
/// snapshot here rather than through `AppUser.fromDoc`, since that
/// factory doesn't know about these two fields.
///
/// Once things settle, it'd be reasonable to fold `streakCount` and
/// `lastCheckInDate` into `AppUser` properly — this is a low-risk way to
/// build the feature now without stepping on in-progress work.
class CheckInService {
  CheckInService._();
  static final instance = CheckInService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// EXP granted per check-in. Scales gently with streak length, capped
  /// so it doesn't run away — tune freely, everything reads through here.
  int dailyExpReward(int streakCount) {
    const base = 20;
    const bonusPerDay = 5;
    const maxBonusDays = 6; // bonus caps out at a 7-day streak
    final bonusDays = streakCount - 1 > maxBonusDays
        ? maxBonusDays
        : (streakCount - 1).clamp(0, maxBonusDays);
    return base + bonusDays * bonusPerDay;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Attempts a daily check-in for [uid]. Safe to call every time the app
  /// opens or a "check in" button is tapped — it's a no-op (returns
  /// [CheckInResult.alreadyCheckedInToday] = true) if already done today.
  Future<CheckInResult> checkIn(String uid) async {
    final userRef = db.collection('users').doc(uid);
    final now = DateTime.now();

    // Step 1: read current streak state and update it in a transaction,
    // without awarding EXP yet (EXP awarding has its own transaction in
    // RewardService, so we keep this one focused on the streak fields
    // only rather than nesting transactions).
    final streakUpdate = await db.runTransaction<_StreakUpdate>((
      transaction,
    ) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? {};

      final rawLastCheckIn = data['lastCheckInDate'] as Timestamp?;
      final lastCheckIn = rawLastCheckIn?.toDate();
      final previousStreak = (data['streakCount'] as num?)?.toInt() ?? 0;

      if (lastCheckIn != null && _isSameDay(lastCheckIn, now)) {
        return _StreakUpdate(
          alreadyCheckedInToday: true,
          streakCount: previousStreak,
        );
      }

      final isConsecutiveDay =
          lastCheckIn != null &&
          _isSameDay(lastCheckIn.add(const Duration(days: 1)), now);

      final newStreak = isConsecutiveDay ? previousStreak + 1 : 1;

      transaction.update(userRef, {
        'streakCount': newStreak,
        'lastCheckInDate': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return _StreakUpdate(
        alreadyCheckedInToday: false,
        streakCount: newStreak,
      );
    });

    if (streakUpdate.alreadyCheckedInToday) {
      return CheckInResult(
        alreadyCheckedInToday: true,
        streakCount: streakUpdate.streakCount,
        expAwarded: 0,
      );
    }

    // Step 2: award the EXP for this check-in as a separate transaction.
    final expAmount = dailyExpReward(streakUpdate.streakCount);
    final awardResult = await RewardService.instance.awardExp(
      uid,
      expAmount,
      reason: 'daily_check_in',
    );

    return CheckInResult(
      alreadyCheckedInToday: false,
      streakCount: streakUpdate.streakCount,
      expAwarded: expAmount,
      levelUpResult: awardResult.leveledUp ? awardResult : null,
    );
  }
}

class _StreakUpdate {
  const _StreakUpdate({
    required this.alreadyCheckedInToday,
    required this.streakCount,
  });
  final bool alreadyCheckedInToday;
  final int streakCount;
}
