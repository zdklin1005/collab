import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/localquest_models.dart';
import '../models/reward_marker.dart';
import 'map_voucher_preview_eligibility.dart';

enum LiveMapVoucherClaimStatus { recorded, alreadyClaimed, voucherUnavailable }

class LiveMapVoucherClaimResult {
  const LiveMapVoucherClaimResult(this.status, {this.campaign});

  final LiveMapVoucherClaimStatus status;
  final Campaign? campaign;
}

class LiveMapVoucherClaimService {
  LiveMapVoucherClaimService({
    FirebaseFirestore? firestore,
    String? Function()? currentUserId,
    DateTime Function()? clock,
  }) : _customFirestore = firestore,
       _currentUserId = currentUserId,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  final String? Function()? _currentUserId;
  final DateTime Function() _clock;

  String? _resolveCurrentUserId() {
    if (_currentUserId != null) return _currentUserId();
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<LiveMapVoucherClaimResult> collect({
    required String uid,
    required RewardMarker reward,
  }) async {
    if (_resolveCurrentUserId() != uid) {
      throw StateError('The signed-in account changed.');
    }

    final voucherId = reward.voucherId?.trim();

    if (reward.type != RewardType.voucher ||
        !reward.hasValidDefinition ||
        voucherId == null ||
        voucherId.isEmpty) {
      return const LiveMapVoucherClaimResult(
        LiveMapVoucherClaimStatus.voucherUnavailable,
      );
    }

    final campaignRef = _firestore.collection('campaigns').doc(voucherId);
    final claimRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('claimedVouchers')
        .doc(voucherId);

    return _firestore.runTransaction((transaction) async {
      if (_resolveCurrentUserId() != uid) {
        throw StateError('The signed-in account changed.');
      }

      final campaignSnapshot = await transaction.get(campaignRef);

      if (!campaignSnapshot.exists) {
        return const LiveMapVoucherClaimResult(
          LiveMapVoucherClaimStatus.voucherUnavailable,
        );
      }

      final campaign = Campaign.fromDoc(campaignSnapshot);
      final businessRef = _firestore
          .collection('businesses')
          .doc(campaign.businessId);
      final businessSnapshot = await transaction.get(businessRef);
      final claimSnapshot = await transaction.get(claimRef);

      if (claimSnapshot.exists) {
        return LiveMapVoucherClaimResult(
          LiveMapVoucherClaimStatus.alreadyClaimed,
          campaign: campaign,
        );
      }

      if (!businessSnapshot.exists) {
        return const LiveMapVoucherClaimResult(
          LiveMapVoucherClaimStatus.voucherUnavailable,
        );
      }

      final business = Business.fromDoc(businessSnapshot);
      final now = _clock();

      final eligibility = checkMapVoucherPreviewEligibility(
        campaign: campaign,
        issuingBusiness: business,
        now: now,
      );

      if (eligibility != MapVoucherPreviewEligibility.eligible ||
          !reward.canDisplayAt(now)) {
        return const LiveMapVoucherClaimResult(
          LiveMapVoucherClaimStatus.voucherUnavailable,
        );
      }

      transaction.set(claimRef, {
        'voucherId': campaign.id,
        'businessId': campaign.businessId,
        'voucherType': campaign.voucherType,
        'collectionMethod': 'walk_up_collect',
        'rewardId': reward.id,
        'checkpointId': reward.checkpointId,
        'claimedAt': FieldValue.serverTimestamp(),
        'redeemed': false,
      });

      transaction.update(campaignRef, {
        'claims': FieldValue.increment(1),
      });

      return LiveMapVoucherClaimResult(
        LiveMapVoucherClaimStatus.recorded,
        campaign: campaign,
      );
    });
  }
}
