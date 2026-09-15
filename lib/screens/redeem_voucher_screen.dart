import 'package:flutter/material.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';

/// Shows a single voucher's details and a "mark as used" action.
///
/// IMPORTANT LIMITATION: there is no merchant-side scanning or
/// verification step anywhere in the app yet. "Mark as used" is
/// self-reported by the tourist — they show this screen to the
/// merchant, the merchant visually checks the code, and the tourist
/// taps the button themselves. This is a trust-based flag, not a
/// secure redemption. A real fix needs a merchant-facing scan/verify
/// screen (out of scope here — coordinate with whoever owns the
/// merchant-side UI before building one, since it'd need matching
/// changes on that side too).
///
/// [voucherDocId] is only used to derive a short, human-readable
/// display code (the last 6 characters of the Firestore doc ID,
/// uppercased) — it is NOT a secure or validated code, purely a
/// reference for the merchant to glance at.
class RedeemVoucherScreen extends StatefulWidget {
  const RedeemVoucherScreen({
    super.key,
    required this.voucherDocId,
    required this.title,
    required this.subtitle,
    required this.initiallyRedeemed,
    required this.onRedeem,
  });

  final String voucherDocId;
  final String title;
  final String subtitle;
  final bool initiallyRedeemed;

  /// Called when the tourist taps "Mark as used" — the caller decides
  /// which Firestore collection/document this actually updates (achievement
  /// voucher vs. claimed merchant voucher use different service methods).
  final Future<void> Function() onRedeem;

  @override
  State<RedeemVoucherScreen> createState() => _RedeemVoucherScreenState();
}

class _RedeemVoucherScreenState extends State<RedeemVoucherScreen> {
  late bool _redeemed = widget.initiallyRedeemed;
  bool _busy = false;

  String get _displayCode {
    final id = widget.voucherDocId;
    final tail = id.length >= 6 ? id.substring(id.length - 6) : id;
    return tail.toUpperCase();
  }

  Future<void> _markRedeemed() async {
    if (_busy || _redeemed) return;
    setState(() => _busy = true);
    try {
      await widget.onRedeem();
      if (mounted) setState(() => _redeemed = true);
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not mark this voucher as used. Please try again.',
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'My rewards'),
          const SizedBox(height: 20),
          LqCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _redeemed
                      ? Icons.check_circle
                      : Icons.confirmation_num_outlined,
                  size: 48,
                  color: _redeemed ? LqColors.success : LqColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LqColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (_redeemed)
                  const Text(
                    'REDEEMED',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: LqColors.success,
                      letterSpacing: 1.2,
                    ),
                  )
                else ...[
                  const Text(
                    'Show this code to the merchant',
                    style: TextStyle(fontSize: 12, color: LqColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _displayCode,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: LqColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (!_redeemed)
            LqButton(
              label: _busy ? 'Marking as used…' : 'Mark as used',
              onPressed: _markRedeemed,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "This voucher has already been used and can't be redeemed again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: LqColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}
