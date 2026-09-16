import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/reward_marker.dart';
import '../../services/live_map_voucher_claim_service.dart';
import 'reward_preview_dialog.dart';

class LiveVoucherClaimDialog extends StatefulWidget {
  const LiveVoucherClaimDialog({
    super.key,
    required this.reward,
    required this.locationName,
    required this.onCollect,
  });

  final RewardMarker reward;
  final String locationName;
  final Future<LiveMapVoucherClaimResult> Function() onCollect;

  @override
  State<LiveVoucherClaimDialog> createState() => _LiveVoucherClaimDialogState();
}

class _LiveVoucherClaimDialogState extends State<LiveVoucherClaimDialog> {
  bool _saving = false;
  String? _message;

  Future<void> _collect() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final result = await widget.onCollect();

      if (!mounted) return;

      switch (result.status) {
        case LiveMapVoucherClaimStatus.recorded:
        case LiveMapVoucherClaimStatus.alreadyClaimed:
          setState(() => _saving = false);
          Navigator.of(context).pop(result);

        case LiveMapVoucherClaimStatus.voucherUnavailable:
          setState(() {
            _saving = false;
            _message =
                'This voucher is no longer available. Choose another marker.';
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
    return PopScope(
      canPop: !_saving,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RewardPreviewDialog(
            reward: widget.reward,
            locationName: widget.locationName,
            isDemo: false,
            noteOverride: _saving
                ? 'Saving your voucher to Rewards…'
                : _message ??
                      'Your location and voucher availability will be checked '
                          'again before it is added to Rewards.',
            onCollect: _saving ? null : _collect,
          ),
          if (_saving)
            const Positioned(bottom: 48, child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
