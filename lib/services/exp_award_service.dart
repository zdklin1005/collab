import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'exp_progress.dart';

class ExpAwardReceipt {
  const ExpAwardReceipt({
    required this.awardId,
    required this.previousExp,
    required this.newExp,
    required this.alreadyAwarded,
  });

  final String awardId;

  // Historical totals for this particular award.
  final int previousExp;
  final int newExp;
  final bool alreadyAwarded;

  int get previousLevel => ExpProgress.fromTotalExp(previousExp).level;
  int get newLevel => ExpProgress.fromTotalExp(newExp).level;
  bool get leveledUp => newLevel > previousLevel;
}

class ExpAwardService {
  ExpAwardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _sources = {'map_exp', 'daily_check_in', 'mission', 'review'};

  /// The source ID identifies the activity, not the attempt.
  ///
  /// Examples:
  /// map_exp: the complete generated reward ID
  /// daily_check_in: the agreed calendar-day identifier
  /// mission: the mission instance ID
  /// review: the review ID
  static String awardIdFor({required String source, required String sourceId}) {
    if (!_sources.contains(source)) {
      throw ArgumentError.value(source, 'source', 'Unsupported EXP source');
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty');
    }

    final encoded = utf8.encode(jsonEncode([source, sourceId]));
    return 'award_v1_${sha256.convert(encoded)}';
  }

  /// Standalone entry point for a previously validated activity.
  ///
  /// Do not use this separately from a map claim transaction.
  Future<ExpAwardReceipt> award({
    required String uid,
    required String source,
    required String sourceId,
    required int amount,
  }) {
    return _firestore.runTransaction(
      (transaction) => awardInTransaction(
        transaction,
        uid: uid,
        source: source,
        sourceId: sourceId,
        amount: amount,
      ),
    );
  }

  /// Allows map claims and EXP updates to share one transaction.
  ///
  /// The caller must finish its other transaction reads first.
  /// After this method, only further transaction writes are allowed.
  /// Never display dialogs or change widget state inside the transaction.
  Future<ExpAwardReceipt> awardInTransaction(
    Transaction transaction, {
    required String uid,
    required String source,
    required String sourceId,
    required int amount,
  }) async {
    if (uid.trim().isEmpty ||
        uid != uid.trim() ||
        uid.contains('/') ||
        uid == '.' ||
        uid == '..') {
      throw ArgumentError.value(uid, 'uid', 'Invalid user ID');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive');
    }

    final awardId = awardIdFor(source: source, sourceId: sourceId);
    final userRef = _firestore.collection('users').doc(uid);
    final logRef = userRef.collection('expLog').doc(awardId);

    // All reads happen before any writes.
    final userSnapshot = await transaction.get(userRef);
    final logSnapshot = await transaction.get(logRef);

    final user = userSnapshot.data();
    if (user == null) {
      throw StateError('The tourist account does not exist.');
    }
    if (user['role'] != 'tourist') {
      throw StateError('EXP awards require a tourist account.');
    }

    final currentExp = user['exp'];
    if (currentExp is! int || currentExp < 0) {
      throw StateError('The account has an invalid EXP balance.');
    }

    final existing = logSnapshot.data();
    if (existing != null) {
      // Reusing an ID with different award details is an error.
      if (existing['source'] != source ||
          existing['sourceId'] != sourceId ||
          existing['amount'] != amount) {
        throw StateError('This award ID already has different details.');
      }

      final previousExp = existing['previousExp'];
      final newExp = existing['newExp'];

      if (previousExp is! int ||
          newExp is! int ||
          previousExp < 0 ||
          newExp < previousExp ||
          newExp - previousExp != amount) {
        throw StateError('The existing EXP award record is invalid.');
      }

      return ExpAwardReceipt(
        awardId: awardId,
        previousExp: previousExp,
        newExp: newExp,
        alreadyAwarded: true,
      );
    }

    final newExp = currentExp + amount;
    if (newExp < currentExp) {
      throw StateError('The EXP balance exceeds the supported range.');
    }

    final progress = ExpProgress.fromTotalExp(newExp);

    transaction.update(userRef, {
      'exp': newExp,
      'level': progress.level,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    transaction.set(logRef, {
      'source': source,
      'sourceId': sourceId,
      'reason': source,
      'amount': amount,
      'previousExp': currentExp,
      'newExp': newExp,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ExpAwardReceipt(
      awardId: awardId,
      previousExp: currentExp,
      newExp: newExp,
      alreadyAwarded: false,
    );
  }
}
