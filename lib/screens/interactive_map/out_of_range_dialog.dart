import 'package:flutter/material.dart';

import 'reward_preview_dialog.dart';

class OutOfRangeDialog extends StatelessWidget {
  const OutOfRangeDialog({
    super.key,
    required this.distanceMeters,
    required this.radiusMeters,
  });

  final double distanceMeters;
  final double radiusMeters;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = distanceMeters < 1000
        ? '${distanceMeters.toStringAsFixed(1)} m'
        : '${(distanceMeters / 1000).toStringAsFixed(2)} km';

    return RewardDialogCard(
      heading: 'Too Far Away!',
      icon: Icons.star_rounded,
      locked: true,
      colors: const [
        Color(0xFFCDD0D5),
        Color(0xFF9CA3AF),
      ],
      title: 'Out of Range',
      description: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text:
                  'You are approximately $distanceLabel away '
                  'in a straight line.\n\n'
                  'The current demo collection radius is ',
            ),
            TextSpan(
              text: '${radiusMeters.toStringAsFixed(0)} metres',
              style: const TextStyle(
                color: Color(0xFF3267D8),
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(text: '.'),
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
          'Do not enter unsafe or restricted areas to reach a reward.\n'
          'Close and tap again to refresh the range check.',
      buttonLabel: 'BACK TO MAP',
      buttonColor: const Color(0xFF6B7280),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}