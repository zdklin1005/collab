import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/localquest_models.dart';
import 'live_business_voucher_availability.dart';
import 'map_voucher_data_validation.dart';

enum LiveBusinessVoucherClaimStatus {
  recorded,
  alreadyClaimed,
  voucherUnavailable,
}

class LiveBusinessVoucherClaimResult {
  const LiveBusinessVoucherClaimResult(this.status, {this.campaign});

  final LiveBusinessVoucherClaimStatus status;
  final Campaign? campaign;
}

class LiveBusinessVoucherClaimService {
  LiveBusinessVoucherClaimService({
    FirebaseFirestore? firestore,
    String? Function()? currentUserId,
    DateTime Function()? clock,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final String? Function() _currentUserId;
  final DateTime Function() _clock;

  Future<LiveBusinessVoucherClaimResult> claim({
    required String uid,
    required String businessId,
    required String voucherId,
  }) async {
    if (_currentUserId() != uid) {
      throw StateError('The signed-in account changed.');
    }

    final cleanBusinessId = businessId.trim();
    final cleanVoucherId = voucherId.trim();

    if (uid.trim().isEmpty ||
        cleanBusinessId.isEmpty ||
        cleanVoucherId.isEmpty) {
      return const LiveBusinessVoucherClaimResult(
        LiveBusinessVoucherClaimStatus.voucherUnavailable,
      );
    }

    final campaignRef = _firestore.collection('campaigns').doc(cleanVoucherId);

    final businessRef = _firestore
        .collection('businesses')
        .doc(cleanBusinessId);

    final claimRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('claimedVouchers')
        .doc(cleanVoucherId);

    return _firestore.runTransaction((transaction) async {
      if (_currentUserId() != uid) {
        throw StateError('The signed-in account changed.');
      }

      final campaignSnapshot = await transaction.get(campaignRef);
      final businessSnapshot = await transaction.get(businessRef);
      final claimSnapshot = await transaction.get(claimRef);

      if (!campaignSnapshot.exists || !businessSnapshot.exists) {
        return const LiveBusinessVoucherClaimResult(
          LiveBusinessVoucherClaimStatus.voucherUnavailable,
        );
      }

      final campaignData = campaignSnapshot.data();

      if (campaignData == null || !hasValidMapVoucherData(campaignData)) {
        return const LiveBusinessVoucherClaimResult(
          LiveBusinessVoucherClaimStatus.voucherUnavailable,
        );
      }

      final campaign = Campaign.fromDoc(campaignSnapshot);

      if (claimSnapshot.exists) {
        return LiveBusinessVoucherClaimResult(
          LiveBusinessVoucherClaimStatus.alreadyClaimed,
          campaign: campaign,
        );
      }

      final business = Business.fromDoc(businessSnapshot);
      final now = _clock();

      final available = availableDiscoveryVouchers(
        business: business,
        campaigns: [campaign],
        now: now,
      );

      if (campaign.businessId != cleanBusinessId ||
          available.length != 1 ||
          available.single.id != cleanVoucherId) {
        return const LiveBusinessVoucherClaimResult(
          LiveBusinessVoucherClaimStatus.voucherUnavailable,
        );
      }

      transaction.set(claimRef, {
        'voucherId': campaign.id,
        'businessId': campaign.businessId,
        'voucherType': campaign.voucherType,
        'collectionMethod': 'discovery_claim',
        'claimedAt': FieldValue.serverTimestamp(),
        'redeemed': false,
      });

      return LiveBusinessVoucherClaimResult(
        LiveBusinessVoucherClaimStatus.recorded,
        campaign: campaign,
      );
    });
  }
}
