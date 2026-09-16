import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';
import '../services/reward_service.dart';

enum _VoucherKind { claimed, achievement }

class _FoundVoucher {
  const _FoundVoucher({
    required this.kind,
    required this.userId,
    required this.voucherId,
    required this.redeemed,
    required this.title,
    required this.subtitle,
  });

  final _VoucherKind kind;
  final String userId;
  final String voucherId;
  final bool redeemed;
  final String title;
  final String subtitle;

  _FoundVoucher copyWith({bool? redeemed}) => _FoundVoucher(
    kind: kind,
    userId: userId,
    voucherId: voucherId,
    redeemed: redeemed ?? this.redeemed,
    title: title,
    subtitle: subtitle,
  );
}

/// Lets a merchant verify and redeem a tourist's voucher by its code.
///
/// Checks claimed campaign vouchers first (scoped to businesses THIS
/// merchant owns, enforced by Firestore rules — a code belonging to a
/// different business silently comes back as "not found", not an error).
/// Falls back to achievement vouchers, which any merchant can verify
/// since they aren't tied to a specific business (see RewardService's
/// class docs on why those are still placeholder-shaped rewards).
class MerchantRedeemVoucherScreen extends StatefulWidget {
  const MerchantRedeemVoucherScreen({super.key, required this.merchant});
  final AppUser merchant;

  @override
  State<MerchantRedeemVoucherScreen> createState() =>
      _MerchantRedeemVoucherScreenState();
}

class _MerchantRedeemVoucherScreenState
    extends State<MerchantRedeemVoucherScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  _FoundVoucher? _found;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });

    try {
      final claimedDoc =
          await MerchantRepository.instance.findClaimedVoucherByCode(code);

      if (claimedDoc != null) {
        final data = claimedDoc.data();
        final voucherId = data['voucherId'] as String? ?? claimedDoc.id;
        final campaignDoc = await FirebaseFirestore.instance
            .collection('campaigns')
            .doc(voucherId)
            .get();
        final campaignData = campaignDoc.data();

        if (mounted) {
          setState(() {
            _found = _FoundVoucher(
              kind: _VoucherKind.claimed,
              userId: claimedDoc.reference.parent.parent!.id,
              voucherId: claimedDoc.id,
              redeemed: data['redeemed'] as bool? ?? false,
              title: campaignData?['name'] as String? ?? 'Merchant voucher',
              subtitle: campaignData == null
                  ? ''
                  : '${(campaignData['discountValue'] as num?)?.toStringAsFixed(0) ?? '?'}'
                        '${campaignData['discountType'] == 'percentage' ? '%' : ' RM'} off',
            );
            _busy = false;
          });
        }
        return;
      }

      final achievementDoc = await RewardService.instance.findByCode(code);

      if (achievementDoc != null) {
        final data = achievementDoc.data();
        final levelReached = data['levelReached'] as num?;
        if (mounted) {
          setState(() {
            _found = _FoundVoucher(
              kind: _VoucherKind.achievement,
              userId: achievementDoc.reference.parent.parent!.id,
              voucherId: achievementDoc.id,
              redeemed: data['redeemed'] as bool? ?? false,
              title: data['source'] == 'level_up'
                  ? 'Level-up reward'
                  : 'Achievement reward',
              subtitle: levelReached != null
                  ? 'Reached level $levelReached · valid at any business'
                  : 'Generic reward · valid at any business',
            );
            _busy = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _error = 'No voucher found with this code for your business.';
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not look up this code. Please try again.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmRedeem() async {
    final found = _found;
    if (found == null || found.redeemed || _busy) return;

    setState(() => _busy = true);
    try {
      if (found.kind == _VoucherKind.claimed) {
        await MerchantRepository.instance.markClaimedVoucherRedeemed(
          found.userId,
          found.voucherId,
        );
      } else {
        await RewardService.instance.markVoucherRedeemed(
          found.userId,
          found.voucherId,
        );
      }
      if (mounted) {
        setState(() => _found = found.copyWith(redeemed: true));
      }
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not redeem this voucher. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Profile'),
          const SizedBox(height: 8),
          const Text(
            'Redeem a voucher',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: LqColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask the tourist for their voucher code and enter it below.',
            style: TextStyle(color: LqColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          LqField(
            controller: _codeController,
            label: 'Voucher code',
            hint: 'e.g. 7KX9QT',
          ),
          const SizedBox(height: 12),
          LqButton(
            label: _busy ? 'Looking up…' : 'Look up code',
            onPressed: _lookup,
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: LqColors.danger)),
          if (_found != null) ...[
            LqCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _found!.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _found!.subtitle,
                    style: const TextStyle(
                      color: LqColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_found!.redeemed)
                    const Text(
                      'This voucher has already been redeemed.',
                      style: TextStyle(
                        color: LqColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    LqButton(
                      label: _busy ? 'Confirming…' : 'Confirm redemption',
                      onPressed: _confirmRedeem,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
