import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/reward_marker.dart';
import '../../services/live_map_exp_claim_service.dart';
import '../../services/map_exp_claim_store.dart';
import 'reward_preview_dialog.dart';

class LiveExpClaimDialog extends StatefulWidget {
  const LiveExpClaimDialog({
    super.key,
    required this.reward,
    required this.locationName,
    required this.onCollect,
  });

  final RewardMarker reward;
  final String locationName;
  final Future<MapExpClaimResult> Function() onCollect;

  @override
  State<LiveExpClaimDialog> createState() => _LiveExpClaimDialogState();
}

class _LiveExpClaimDialogState extends State<LiveExpClaimDialog> {
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

      // Restore normal route popping before returning the result.
      setState(() {
        _saving = false;
      });

      Navigator.of(context).pop(result);
    } on MapExpClaimBlocked catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _message = error.message;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _message = switch (error.code) {
          'permission-denied' =>
            'Firebase did not allow this claim. Check the published map '
                'claim rules before retrying.',
          'unavailable' =>
            'Could not confirm the save. Reconnect and retry. '
                'The same reward will not be awarded twice.',
          'unauthenticated' =>
            'Please sign in again before collecting.',
          _ =>
            'Could not confirm the collection. Return to the map '
                'and refresh your reward history before retrying.',
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _message =
            'Could not confirm the collection. Return to the map '
            'and refresh your reward history before retrying.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: _saving
          ? const AlertDialog(
              title: Text('Collecting EXP'),
              content: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Checking and saving your collection…'),
                  ),
                ],
              ),
            )
          : RewardPreviewDialog(
              reward: widget.reward,
              locationName: widget.locationName,
              isDemo: false,
              noteOverride:
                  _message ??
                  'Your location and reward availability will be checked '
                      'again before EXP is added to your account.',
              onCollect: _collect,
            ),
    );
  }
}