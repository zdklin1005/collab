import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/localquest_models.dart';
import 'exp_progress.dart';

/// Represents the user's progress within their current level.
class LevelProgress {
  const LevelProgress({
    required this.currentLevel,
    required this.currentExp,
    required this.floorExp,
    required this.nextLevelExp,
    required this.expInLevel,
    required this.levelSpan,
    required this.progress,
  });

  final int currentLevel;
  final int currentExp;
  final int floorExp;
  final int nextLevelExp;
  final int expInLevel;
  final int levelSpan;
  final double progress;

  /// Progress label showing current EXP vs next level target, e.g. "591/600XP"
  String get expLabel {
    final nf = NumberFormat('#,##0');
    return '${nf.format(currentExp)}/${nf.format(nextLevelExp)}XP';
  }
}

import 'exp_progress.dart';
import 'exp_award_service.dart';

/// Result of awarding EXP to a tourist, including whether they leveled up
/// and how many vouchers were awarded as a result.
class ExpAwardResult {
  const ExpAwardResult({
    required this.previousLevel,
    required this.newLevel,
    required this.previousExp,
    required this.newExp,
    required this.vouchersAwarded,
  });

  final int previousLevel;
  final int newLevel;
  final int previousExp;
  final int newExp;
  final int vouchersAwarded;

  bool get leveledUp => newLevel > previousLevel;
  int get levelsGained => newLevel - previousLevel;
}

/// Handles EXP accumulation, leveling, and voucher awarding for tourists.
///
/// Builds directly on the existing `users/{uid}` document rather than a
/// separate collection, since `exp`, `level`, and `voucherCount` already
/// live on [AppUser]. Follows the same singleton pattern as
/// `UserRepository` / `MerchantRepository` in localquest_services.dart.
class RewardService {
  RewardService._();
  RewardService.withFirestore(FirebaseFirestore firestore) : _db = firestore;
  static final instance = RewardService._();

  FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore customDb) => _db = customDb;

  /// EXP curve: total cumulative EXP required to *reach* [level].
  /// Level 1 requires 0 EXP (everyone starts here).
  int expRequiredForLevel(int level) {
    // Preserve the existing RewardService behaviour for levels <= 1.
    return ExpProgress.expRequiredForLevel(level <= 1 ? 1 : level);
  }

  int levelForExp(int exp) {
    // Preserve its existing fallback for negative input.
    return ExpProgress.fromTotalExp(exp < 0 ? 0 : exp).level;
  }

  int expToNextLevel(int exp) {
    final progress = ExpProgress.fromTotalExp(exp < 0 ? 0 : exp);
    // Preserve the existing result for negative input too.
    return progress.nextLevelExp - exp;
  }

  /// Returns detailed level progress metrics for a given cumulative [exp].
  /// Optionally accepts [currentLevel] if the stored user document has an
  /// explicit level.
  LevelProgress getLevelProgress(int exp, [int? currentLevel]) {
    final progress = ExpProgress.fromTotalExp(exp < 0 ? 0 : exp, currentLevel);
    return LevelProgress(
      currentLevel: progress.level,
      currentExp: progress.totalExp,
      floorExp: progress.levelStartExp,
      nextLevelExp: progress.nextLevelExp,
      expInLevel: progress.expIntoLevel,
      levelSpan: progress.expRequiredThisLevel,
      progress: progress.fraction,
    );
  }

  /// Adds [amount] EXP to the tourist identified by [uid], recalculates
  /// their level, and awards one voucher per level gained.
  ///
  /// Uses a Firestore transaction so concurrent EXP awards (e.g. two
  /// quick pickups from the map module firing close together) can't race
  /// and silently drop EXP.
  ///
  /// NOTE: the actual voucher being awarded (which business, what
  /// discount) isn't modeled yet on the merchant side — this writes a
  /// placeholder record to `users/{uid}/vouchers` so there's something
  /// to display and count, and it can be enriched once a real voucher
  /// shape exists in the Promotional Configuration module.
  Future<ExpAwardResult> awardExp(
    String uid,
    int amount, {
    String reason = 'exp_collected',
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }

    final userRef = db.collection('users').doc(uid);

    return db.runTransaction<ExpAwardResult>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final user = AppUser.fromDoc(snapshot);

      final previousExp = user.exp;
      final previousLevel = user.level;
      final newExp = previousExp + amount;
      final newLevel = levelForExp(newExp);
      final levelsGained = newLevel - previousLevel;

      transaction.update(userRef, {
        'exp': newExp,
        'level': newLevel,
        if (levelsGained > 0)
          'voucherCount': FieldValue.increment(levelsGained),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var i = 0; i < levelsGained; i++) {
        final voucherRef = userRef.collection('vouchers').doc();
        transaction.set(voucherRef, {
          'source': 'level_up',
          'levelReached': previousLevel + i + 1,
          'awardedAt': FieldValue.serverTimestamp(),
          'redeemed': false,
        });
      }

      // Activity log for the EXP gain itself, useful for a history feed
      // and for debugging "why did my EXP change" during development.
      final logRef = userRef.collection('expLog').doc();
      transaction.set(logRef, {
        'amount': amount,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return ExpAwardResult(
        previousLevel: previousLevel,
        newLevel: newLevel,
        previousExp: previousExp,
        newExp: newExp,
        vouchersAwarded: levelsGained,
      );
    });
  }

  /// Awards a single voucher to [uid] outside of the leveling flow (e.g.
  /// for completing a voucher-reward mission). Increments `voucherCount`
  /// on the user doc and writes the same placeholder voucher record
  /// shape used by [awardExp]'s level-up path — see the note there about
  /// this being a stand-in until a real voucher shape exists.
  Future<void> awardVoucher(String uid, {required String source}) async {
    final userRef = db.collection('users').doc(uid);
    final voucherRef = userRef.collection('vouchers').doc();

    final batch = db.batch();
    batch.update(userRef, {'voucherCount': FieldValue.increment(1)});
    batch.set(voucherRef, {
      'source': source,
      'awardedAt': FieldValue.serverTimestamp(),
      'redeemed': false,
    });
    await batch.commit();
  }

  /// Live list of achievement vouchers (from level-ups / voucher-type
  /// missions) awarded to [uid].
  Stream<List<Map<String, dynamic>>> watchAchievementVouchers(String uid) {
    try {
      return db
          .collection('users')
          .doc(uid)
          .collection('vouchers')
          .orderBy('awardedAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
          );
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Marks an achievement voucher as used.
  Future<void> markVoucherRedeemed(String uid, String voucherId) {
    return db
        .collection('users')
        .doc(uid)
        .collection('vouchers')
        .doc(voucherId)
        .update({'redeemed': true, 'redeemedAt': FieldValue.serverTimestamp()});
  }

  static String mapExpAwardIdFor(String rewardId) {
    return ExpAwardService.awardIdFor(source: 'map_exp', sourceId: rewardId);
  }

  /// Used only within a validated map-claim transaction.
  ///
  /// The transaction must belong to this service's Firestore instance.
  /// Finish other transaction reads before calling this method.
  /// Do not call awardExp() afterward: that would award EXP twice.
  ///
  /// This does not issue the teammate's separate level-up reward.
  Future<ExpAwardReceipt> awardMapExpInTransaction(
    Transaction transaction, {
    required String uid,
    required String rewardId,
    required int amount,
  }) {
    return ExpAwardService(firestore: db).awardInTransaction(
      transaction,
      uid: uid,
      source: 'map_exp',
      sourceId: rewardId,
      amount: amount,
    );
  }
}
