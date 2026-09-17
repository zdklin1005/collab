import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'voucher_code.dart';
import '../models/localquest_models.dart';
import 'exp_award_service.dart';
import '../services/exp_progress.dart';
import 'localquest_services.dart';

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

/// Result of awarding EXP to a tourist, including whether they leveled up
/// and how many real campaign vouchers were actually granted as a result
/// (see RewardService.awardExp()'s doc comment — this can be less than
/// the number of levels gained if no active campaign was available at
/// grant time).
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
  static final instance = RewardService._();

  /// Creates a RewardService instance bound to a specific Firestore
  /// instance, rather than the shared singleton's db — used by
  /// MapExpClaimStore so map-EXP awards run against the exact Firestore
  /// instance the surrounding transaction is on.
  factory RewardService.withFirestore(FirebaseFirestore firestore) {
    final service = RewardService._();
    service.db = firestore;
    return service;
  }

  FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore customDb) => _db = customDb;
  final Random _random = Random();

  /// EXP curve: total cumulative EXP required to *reach* [level].
  /// Delegates to ExpProgress, the single source of truth shared with
  /// MapProgressCard and the tourist profile screen.
  int expRequiredForLevel(int level) => ExpProgress.expRequiredForLevel(level);

  /// The level a given cumulative EXP total corresponds to.
  int levelForExp(int exp) =>
      ExpProgress.fromTotalExp(exp < 0 ? 0 : exp).level;

  /// EXP still needed to reach the next level from [exp] (0 at max level).
  int expToNextLevel(int exp) =>
      ExpProgress.fromTotalExp(exp < 0 ? 0 : exp).expToNextLevel;

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

  /// Adds [amount] EXP to the tourist identified by [uid] and recalculates
  /// their level.
  ///
  /// Uses a Firestore transaction so concurrent EXP awards (e.g. two
  /// quick pickups from the map module firing close together) can't race
  /// and silently drop EXP.
  ///
  /// If this crosses one or more level thresholds, a real merchant
  /// campaign voucher is granted per level gained via
  /// [MerchantRepository.claimVoucher] — deliberately run AFTER the
  /// transaction above commits, not nested inside it. Firestore
  /// transactions can retry silently on contention; nesting a
  /// multi-step operation like claimVoucher() inside one risks it
  /// firing more than once per retry. Voucher campaigns aren't scoped
  /// to the tourist's location, since several EXP-awarding call sites
  /// (check-in, review submission) don't have GPS context available —
  /// only mission completion does — so this picks from ALL currently
  /// active voucher campaigns regardless of city. If none are active at
  /// grant time, the level-up itself still happens; it just doesn't
  /// come with a bonus voucher that time.
  Future<ExpAwardResult> awardExp(
      String uid,
      int amount, {
        String reason = 'exp_collected',
      }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }

    final userRef = db.collection('users').doc(uid);

    final result = await db.runTransaction<ExpAwardResult>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final user = AppUser.fromDoc(snapshot);

      final previousExp = user.exp;
      final previousLevel = user.level;
      final newExp = previousExp + amount;
      final newLevel = levelForExp(newExp);

      transaction.update(userRef, {
        'exp': newExp,
        'level': newLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
        vouchersAwarded: 0, // filled in below, after the transaction commits
      );
    });

    if (result.levelsGained <= 0) return result;

    final usedCampaignIds = <String>{};
    var granted = 0;
    for (var i = 0; i < result.levelsGained; i++) {
      final campaignId = await _grantLevelUpVoucher(uid, usedCampaignIds);
      if (campaignId != null) {
        usedCampaignIds.add(campaignId);
        granted++;
      }
    }

    return ExpAwardResult(
      previousLevel: result.previousLevel,
      newLevel: result.newLevel,
      previousExp: result.previousExp,
      newExp: result.newExp,
      vouchersAwarded: granted,
    );
  }

  /// Attempts to grant one real campaign voucher for a level-up. Prefers
  /// a campaign not already used earlier in this same award call
  /// ([excludeCampaignIds]) so multiple level-ups from one big EXP award
  /// don't all hand out the same voucher when several are active; falls
  /// back to reusing one if that's all that's available. Returns the
  /// campaign id used, or null if no active voucher campaign exists at
  /// all right now.
  ///
  /// NOTE: MerchantRepository.claimVoucher() only blocks a duplicate
  /// claim for 'welcome'-type campaigns — 'promotional'/'seasonal'
  /// campaigns don't currently enforce perCustomerLimit/quantity at
  /// claim time. That's a pre-existing gap in the merchant module, not
  /// something specific to level-up grants, but worth knowing: a
  /// tourist leveling up repeatedly while only one non-welcome campaign
  /// is active could claim it more than once.
  Future<String?> _grantLevelUpVoucher(
      String uid,
      Set<String> excludeCampaignIds,
      ) async {
    try {
      final snap = await db
          .collection('campaigns')
          .where('type', isEqualTo: 'voucher')
          .where('status', isEqualTo: 'active')
          .limit(20)
          .get();
      if (snap.docs.isEmpty) return null;

      final campaigns = snap.docs.map(Campaign.fromDoc).toList();
      final fresh = campaigns
          .where((c) => !excludeCampaignIds.contains(c.id))
          .toList();
      final pool = fresh.isNotEmpty ? fresh : campaigns;
      final campaign = pool[_random.nextInt(pool.length)];

      await MerchantRepository.instance.claimVoucher(
        userId: uid,
        voucherId: campaign.id,
        businessId: campaign.businessId,
        voucherType: campaign.voucherType,
      );
      return campaign.id;
    } catch (_) {
      // e.g. already claimed (welcome-type dedup) or a transient error —
      // the level-up itself already happened; just no bonus voucher.
      return null;
    }
  }

  /// Awards a single voucher to [uid] outside of the leveling flow (e.g.
  /// for completing a voucher-reward mission). Increments `voucherCount`
  /// on the user doc and writes a placeholder voucher record — see the
  /// class doc on awardVoucher() for why this is a stand-in until a real
  /// voucher shape exists for this specific call site.
  Future<void> awardVoucher(String uid, {required String source}) async {
    final userRef = db.collection('users').doc(uid);
    final voucherRef = userRef.collection('vouchers').doc();

    final batch = db.batch();
    batch.update(userRef, {'voucherCount': FieldValue.increment(1)});
    batch.set(voucherRef, {
      'source': source,
      'awardedAt': FieldValue.serverTimestamp(),
      'redeemed': false,
      'code': VoucherCode.generate(),
    });
    await batch.commit();
  }

  /// Live list of achievement vouchers (from voucher-type missions)
  /// awarded to [uid]. Raw maps, not a dedicated model — see the class
  /// doc on awardVoucher() for why these are placeholders. No longer
  /// includes level-up vouchers, which are now real campaign vouchers
  /// living in claimedVouchers instead (see MyRewardsScreen).
  Stream<List<Map<String, dynamic>>> watchAchievementVouchers(String uid) {
    try {
      return db
          .collection('users').doc(uid).collection('vouchers')
          .orderBy('awardedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Marks an achievement voucher as used. Self-reported by the tourist —
  /// see RedeemVoucherScreen's class doc for the trust-model caveat.
  Future<void> markVoucherRedeemed(String uid, String voucherId) {
    return db
        .collection('users').doc(uid).collection('vouchers').doc(voucherId)
        .update({'redeemed': true, 'redeemedAt': FieldValue.serverTimestamp()});
  }

  /// Looks up an achievement voucher by its code, across ALL tourists —
  /// achievement vouchers aren't tied to a specific business, so any
  /// signed-in merchant can verify one. Returns null if no match.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> findByCode(
      String code,
      ) async {
    final snap = await db
        .collectionGroup('vouchers')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
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
  /// This does not issue a level-up voucher directly — if it crosses a
  /// level threshold, that's picked up the next time the tourist's
  /// profile reads their level normally; map EXP goes through this
  /// dedicated transactional path instead of awardExp() specifically so
  /// it can share the caller's Firestore transaction, which precludes
  /// also calling out to claimVoucher() here for the same reason
  /// awardExp() defers its own voucher grant until after its
  /// transaction commits.
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