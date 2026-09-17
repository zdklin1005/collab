import 'package:flutter/material.dart';

import 'reward_preview_dialog.dart';

class OutOfRangeDialog extends StatelessWidget {
  const OutOfRangeDialog({
    super.key,
    required this.distanceMeters,
    required this.radiusMeters,
    required this.onGetCloser,
    this.isDemo = true,
  });

  final double distanceMeters;
  final double radiusMeters;
  final VoidCallback onGetCloser;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return RewardDialogCard(
      heading: 'Too Far Away!',
      icon: Icons.star_rounded,
      locked: true,
      colors: const [Color(0xFFCDD0D5), Color(0xFF9CA3AF)],
      title: 'Out of Range',
      description: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text:
                  'You are currently too far from this reward.\n'
                  'You need to be within ',
            ),
            TextSpan(
              text: '${radiusMeters.toStringAsFixed(0)} meters',
              style: const TextStyle(
                color: Color(0xFF3267D8),
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(text: ' to collect it. Keep moving!'),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 16,
          height: 1.5,
        ),
      ),
      note:
          'Do not enter unsafe or restricted areas. '
          'Tap the marker again to refresh the range check.',
      buttonLabel: 'GET CLOSER',
      buttonColor: const Color(0xFF6B7280),
      onPressed: onGetCloser,
    );
  }
}
