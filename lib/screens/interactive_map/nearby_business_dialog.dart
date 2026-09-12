import 'package:flutter/material.dart';

import '../../models/localquest_models.dart';
import '../../services/daily_reward_generator.dart';
import 'business_voucher_section.dart';
import 'business_voucher_claim_check.dart';

class NearbyBusinessDialog extends StatefulWidget {
  const NearbyBusinessDialog({
    super.key,
    required this.business,
    required this.distanceMeters,
    required this.offers,
    required this.onDismiss,
    required this.onViewDetails,
    this.onCheckEligibility,
    this.onClaim,
    this.initialOffer,
    this.now,
  });

  final Business business;
  final double distanceMeters;
  final List<MapVoucherOffer> offers;
  final VoidCallback onDismiss;
  final VoidCallback onViewDetails;
  final Future<BusinessVoucherClaimStatus> Function(String voucherId)?
  onCheckEligibility;
  final Future<BusinessVoucherClaimStatus> Function(String voucherId)? onClaim;
  final MapVoucherOffer? initialOffer;

  // Tests can supply a fixed time.
  final DateTime Function()? now;

  @override
  State<NearbyBusinessDialog> createState() => _NearbyBusinessDialogState();
}

class _NearbyBusinessDialogState extends State<NearbyBusinessDialog> {
  MapVoucherOffer? _selectedOffer;

  bool _checkingEligibility = false;
  bool _claimConfirmed = false;
  String? _eligibilityMessage;

  @override
  void initState() {
    super.initState();
    _selectedOffer = widget.initialOffer;
  }

  Future<void> _checkEligibility() async {
    final selected = _selectedOffer;
    final check = widget.onClaim ?? widget.onCheckEligibility;

    if (selected == null ||
        check == null ||
        _checkingEligibility ||
        _claimConfirmed) {
      return;
    }

    setState(() {
      _checkingEligibility = true;
      _eligibilityMessage = null;
    });

    try {
      final status = await check(selected.id);
      if (!mounted) return;

      setState(() {
        _claimConfirmed =
            status == BusinessVoucherClaimStatus.demoRecorded ||
            status == BusinessVoucherClaimStatus.alreadyClaimed;

        _eligibilityMessage = switch (status) {
          BusinessVoucherClaimStatus.readyForDemo =>
            'Local checks passed at this moment. '
                'This offer is not recorded as claimed in your local demo history. '
                'No voucher was claimed. Live stock is not verified.',
          BusinessVoucherClaimStatus.alreadyClaimed =>
            'You have already claimed this offer in the demo. '
                'Each tourist can claim this specific offer only once.',
          BusinessVoucherClaimStatus.historyUnavailable =>
            'Claim history is not ready. '
                'Close this preview and retry loading history on Discover.',
          BusinessVoucherClaimStatus.accountRequired =>
            'The tourist account changed or is unavailable. '
                'Close this preview and sign in again.',
          BusinessVoucherClaimStatus.appInactive =>
            'Return to Discover and check again.',
          BusinessVoucherClaimStatus.voucherUnavailable =>
            'This voucher is unavailable for this business.',
          BusinessVoucherClaimStatus.locationAccessRequired =>
            'Enable location permission and location services.',
          BusinessVoucherClaimStatus.locationUnavailable =>
            'Wait for a fresh location update, then check again.',
          BusinessVoucherClaimStatus.locationUnreliable =>
            'GPS is stale or not accurate enough. Try again later.',
          BusinessVoucherClaimStatus.invalidCoordinates =>
            'The business or tourist coordinates are invalid.',
          BusinessVoucherClaimStatus.outOfRange =>
            'You are outside the demo business-voucher claim radius.',
          BusinessVoucherClaimStatus.demoRecorded =>
            'Success! Your demo business-voucher claim was saved. '
                'This offer cannot be claimed again by this tourist. '
                'Real voucher delivery to Rewards is not connected yet.',
          BusinessVoucherClaimStatus.claimInProgress =>
            'Another business-voucher claim is being processed. '
                'Please wait and try again.',
          BusinessVoucherClaimStatus.saveFailed =>
            'The save could not be confirmed. '
                'Please retry; no success has been confirmed.',
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _eligibilityMessage =
            'Could not complete the check. Please try again. '
            'No voucher was claimed.';
      });
    } finally {
      if (mounted) {
        setState(() => _checkingEligibility = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOffer;
    final checkedAt = widget.now?.call() ?? DateTime.now();

    return AlertDialog(
      icon: Icon(
        selected == null
            ? Icons.storefront_outlined
            : Icons.confirmation_number_outlined,
        color: const Color(0xFF3267D8),
        size: 36,
      ),
      title: Text(selected == null ? 'Business nearby' : 'Review voucher'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.business.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (selected == null) ...[
              Text(
                widget.business.category.trim().isEmpty
                    ? 'Uncategorised'
                    : widget.business.category,
              ),
              const SizedBox(height: 8),
              Text(
                widget.initialOffer != null
                    ? 'Opened from business details. '
                          'Your range is checked when claiming.'
                    : 'Approximately '
                          '${widget.distanceMeters.toStringAsFixed(0)} m '
                          'away in a straight line when detected.',
              ),
              const SizedBox(height: 16),
              BusinessVoucherSection(
                business: widget.business,
                offers: widget.offers,
                checkedAt: checkedAt,
                onSelected: (offer) {
                  setState(() {
                    _selectedOffer = offer;
                    _claimConfirmed = false;
                    _eligibilityMessage = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Merchant promotions are not connected yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ] else ...[
              Text(
                selected.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Demo stock when listed: '
                '${selected.remainingStock}',
              ),
              const SizedBox(height: 12),
              Text(
                _claimConfirmed
                    ? 'This offer is recorded as claimed in your local demo history.'
                    : 'Selecting this voucher does not claim it.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Claiming rechecks your location, offer validity and local history '
                'before saving a demo claim. Real stock and voucher delivery '
                'are not connected.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              if (_eligibilityMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _eligibilityMessage!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onDismiss, child: const Text('Dismiss')),
        if (selected == null)
          FilledButton(
            onPressed: widget.onViewDetails,
            child: const Text('View details'),
          )
        else ...[
          TextButton(
            onPressed: _checkingEligibility
                ? null
                : () {
                    if (widget.initialOffer != null) {
                      // Opened from business details:
                      // close this dialog to reveal its voucher section.
                      widget.onDismiss();
                      return;
                    }

                    // Opened from the nearby-business popup:
                    // return to that popup's voucher list.
                    setState(() {
                      _selectedOffer = null;
                      _eligibilityMessage = null;
                      _claimConfirmed = false;
                    });
                  },
            child: const Text('Back to vouchers'),
          ),
          FilledButton(
            onPressed:
                (widget.onClaim == null && widget.onCheckEligibility == null) ||
                    _checkingEligibility ||
                    _claimConfirmed
                ? null
                : _checkEligibility,
            child: Text(
              _checkingEligibility
                  ? 'Processing…'
                  : _claimConfirmed
                  ? 'Already claimed'
                  : widget.onClaim != null
                  ? 'Claim demo voucher'
                  : 'Check eligibility',
            ),
          ),
        ],
      ],
    );
  }
}
