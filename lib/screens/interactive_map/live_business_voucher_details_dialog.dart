import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/localquest_models.dart';
import '../../services/live_business_voucher_claim_service.dart';
import '../../services/localquest_services.dart';
import 'live_business_voucher_collection_check.dart';

class LiveBusinessVoucherDetailsDialog extends StatefulWidget {
  const LiveBusinessVoucherDetailsDialog({
    super.key,
    required this.campaign,
    this.onCheck,
    this.onClaim,
  });

  final Campaign campaign;
  final Future<LiveBusinessVoucherCollectionCheck> Function()? onCheck;
  final Future<LiveBusinessVoucherClaimResult> Function()? onClaim;

  @override
  State<LiveBusinessVoucherDetailsDialog> createState() =>
      _LiveBusinessVoucherDetailsDialogState();
}

class _LiveBusinessVoucherDetailsDialogState
    extends State<LiveBusinessVoucherDetailsDialog> {
  bool _saving = false;
  bool _alreadyClaimed = false;
  String? _message;

  Campaign get campaign => widget.campaign;

  @override
  void initState() {
    super.initState();
    MerchantRepository.instance.recordCampaignView(widget.campaign.id);
  }

  String _discountLabel() {
    if (campaign.discountValue <= 0) {
      return 'Offer details provided by the merchant';
    }

    if (campaign.discountType == 'percentage') {
      return '${campaign.discountValue.toStringAsFixed(0)}% discount';
    }

    return 'RM ${campaign.discountValue.toStringAsFixed(2)} discount';
  }

  String _checkMessage(LiveBusinessVoucherCollectionCheck check) {
    return switch (check.status) {
      LiveBusinessVoucherCollectionStatus.ready => '',
      LiveBusinessVoucherCollectionStatus.accountRequired =>
        'Sign in again before claiming this voucher.',
      LiveBusinessVoucherCollectionStatus.appInactive =>
        'Return to Discover and try again.',
      LiveBusinessVoucherCollectionStatus.voucherUnavailable =>
        'This voucher is no longer available.',
      LiveBusinessVoucherCollectionStatus.locationAccessRequired =>
        'Enable location permission and location services.',
      LiveBusinessVoucherCollectionStatus.locationUnavailable =>
        'Wait for your current location, then try again.',
      LiveBusinessVoucherCollectionStatus.locationUnreliable =>
        'Your GPS location is not accurate or recent enough. Try again outside.',
      LiveBusinessVoucherCollectionStatus.invalidCoordinates =>
        'The business location is unavailable.',
      LiveBusinessVoucherCollectionStatus.outOfRange =>
        'You are too far from this business. '
            'Move closer before claiming this voucher.',
    };
  }

  Future<void> _claim() async {
    final checkClaim = widget.onCheck;
    final saveClaim = widget.onClaim;

    if (_saving || _alreadyClaimed || checkClaim == null || saveClaim == null) {
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final check = await checkClaim();

      if (!mounted) return;

      if (!check.canClaim) {
        setState(() {
          _saving = false;
          _message = _checkMessage(check);
        });
        return;
      }

      final result = await saveClaim();

      if (!mounted) return;

      switch (result.status) {
        case LiveBusinessVoucherClaimStatus.recorded:
          setState(() => _saving = false);
          Navigator.of(context).pop(result);

        case LiveBusinessVoucherClaimStatus.alreadyClaimed:
          setState(() {
            _saving = false;
            _alreadyClaimed = true;
            _message =
                'You have already claimed this voucher. '
                'Each tourist can claim this offer only once.';
          });

        case LiveBusinessVoucherClaimStatus.voucherUnavailable:
          setState(() {
            _saving = false;
            _message = 'This voucher is no longer available.';
          });
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _message = switch (error.code) {
          'permission-denied' => 'Firebase did not allow this voucher claim.',
          'unavailable' => 'The connection is unavailable. Please try again.',
          'unauthenticated' => 'Sign in again before claiming this voucher.',
          _ => 'The voucher could not be saved. Please try again.',
        };
      });
    } on StateError {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _message = 'The account changed. Sign in again and retry.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _message = 'The voucher could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = campaign.quantity - campaign.claims;
    final dates = MaterialLocalizations.of(context);
    final claimingEnabled = widget.onCheck != null && widget.onClaim != null;

    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        icon: const Icon(
          Icons.confirmation_number_outlined,
          color: Color(0xFF3267D8),
          size: 38,
        ),
        title: Text(campaign.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _discountLabel(),
                style: const TextStyle(
                  color: Color(0xFF3267D8),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (campaign.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(campaign.description.trim()),
              ],
              const SizedBox(height: 16),
              Text('$remaining voucher${remaining == 1 ? '' : 's'} remaining'),
              if (campaign.minimumSpend > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Minimum spend: '
                  'RM ${campaign.minimumSpend.toStringAsFixed(2)}',
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Valid from '
                '${dates.formatMediumDate(campaign.startDate.toLocal())} '
                'until '
                '${dates.formatMediumDate(campaign.endDate.toLocal())}',
              ),
              if (campaign.validDays?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Valid days: ${campaign.validDays!.trim()}'),
              ],
              if (campaign.effectiveHours?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Valid hours: ${campaign.effectiveHours!.trim()}'),
              ],
              const SizedBox(height: 16),
              const Text(
                'Terms and conditions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                campaign.terms.trim().isEmpty
                    ? 'No additional terms were provided.'
                    : campaign.terms.trim(),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  key: const ValueKey('live-business-voucher-claim-message'),
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('close-live-business-voucher-details'),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Back to vouchers'),
          ),
          if (claimingEnabled)
            FilledButton(
              key: const ValueKey('claim-live-business-voucher'),
              onPressed: _saving || _alreadyClaimed ? null : _claim,
              child: Text(
                _saving
                    ? 'Claiming…'
                    : _alreadyClaimed
                    ? 'Already claimed'
                    : 'Claim voucher',
              ),
            ),
        ],
      ),
    );
  }
}
