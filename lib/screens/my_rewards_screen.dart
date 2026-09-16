import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';
import '../services/reward_service.dart';
import 'redeem_voucher_screen.dart';

/// Tourist's rewards, split into two sections since they come from two
/// unrelated systems that were never unified (see the note on
/// RewardService.awardVoucher() and MerchantRepository.claimVoucher()):
/// real merchant-issued campaign vouchers the tourist claimed, and
/// generic achievement vouchers earned from leveling up or completing
/// voucher-type missions.
class MyRewardsScreen extends StatelessWidget {
  const MyRewardsScreen({
    super.key,
    required this.userId,
    this.showBackButton = true,
  });
  final String userId;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) => LqPage(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            const LqBackButton(label: 'Profile'),
            const SizedBox(height: 8),
          ],
          const Text(
            'My rewards',
            style: TextStyle(
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: LqColors.ink,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MERCHANT VOUCHERS', style: monoLabel),
                  const SizedBox(height: 10),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    initialData: const [],
                    stream: MerchantRepository.instance.touristClaimedVouchers(userId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final claimed = snapshot.data!;
                      if (claimed.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No claimed merchant vouchers yet.',
                            style: TextStyle(color: LqColors.muted, fontSize: 13),
                          ),
                        );
                      }
                      return Column(
                        children: claimed
                            .map((data) => _ClaimedVoucherCard(userId: userId, data: data))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text('ACHIEVEMENT REWARDS', style: monoLabel),
                  const SizedBox(height: 10),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    initialData: const [],
                    stream: RewardService.instance.watchAchievementVouchers(userId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final vouchers = snapshot.data!;
                      if (vouchers.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Level up or complete voucher missions to earn rewards here.',
                            style: TextStyle(color: LqColors.muted, fontSize: 13),
                          ),
                        );
                      }
                      return Column(
                        children: vouchers
                            .map((data) => _AchievementVoucherCard(userId: userId, data: data))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClaimedVoucherCard extends StatelessWidget {
  const _ClaimedVoucherCard({required this.userId, required this.data});
  final String userId;
  final Map<String, dynamic> data;

  Future<Campaign?> _fetchCampaign(String voucherId) async {
    if (voucherId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(voucherId)
          .get();
      return doc.exists ? Campaign.fromDoc(doc) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final voucherId = data['id'] as String? ?? data['voucherId'] as String? ?? '';
    final redeemed = data['redeemed'] as bool? ?? false;

    return FutureBuilder<Campaign?>(
      future: _fetchCampaign(voucherId),
      builder: (context, campaignSnap) {
        final campaign = campaignSnap.data;
        final title = campaign?.name ?? 'Merchant voucher';
        final discount = campaign == null
            ? 'Merchant voucher'
            : campaign.discountType == 'percentage'
                ? '${campaign.discountValue.toStringAsFixed(0)}% off'
                : 'RM${campaign.discountValue.toStringAsFixed(2)} off';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RedeemVoucherScreen(
                  voucherDocId: voucherId,
                  title: title,
                  subtitle: discount,
                  initiallyRedeemed: redeemed,
                  onRedeem: () => MerchantRepository.instance
                      .markClaimedVoucherRedeemed(userId, voucherId),
                ),
              ),
            ),
            child: LqCard(
              padding: const EdgeInsets.all(16),
              child: Opacity(
                opacity: redeemed ? 0.5 : 1,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE0C4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.confirmation_num_outlined,
                        color: Color(0xFF8A5A22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            discount,
                            style: const TextStyle(
                              color: LqColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      redeemed ? 'Redeemed' : 'Tap to use',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: redeemed ? LqColors.muted : LqColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AchievementVoucherCard extends StatelessWidget {
  const _AchievementVoucherCard({required this.userId, required this.data});
  final String userId;
  final Map<String, dynamic> data;

  String _sourceLabel(String? source) => switch (source) {
    'level_up' => 'Level-up reward',
    'mission_completed' => 'Mission reward',
    _ => 'Achievement reward',
  };

  @override
  Widget build(BuildContext context) {
    final voucherId = data['id'] as String? ?? '';
    final redeemed = data['redeemed'] as bool? ?? false;
    final source = data['source'] as String?;
    final levelReached = data['levelReached'] as num?;
    final title = _sourceLabel(source);
    final subtitle = levelReached != null
        ? 'Reached level $levelReached'
        : 'Earned reward';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RedeemVoucherScreen(
              voucherDocId: voucherId,
              title: title,
              subtitle: subtitle,
              initiallyRedeemed: redeemed,
              onRedeem: () =>
                  RewardService.instance.markVoucherRedeemed(userId, voucherId),
            ),
          ),
        ),
        child: LqCard(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: redeemed ? 0.5 : 1,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: LqColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: LqColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: LqColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  redeemed ? 'Redeemed' : 'Tap to use',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: redeemed ? LqColors.muted : LqColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
