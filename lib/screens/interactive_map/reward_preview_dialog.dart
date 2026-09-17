import 'package:flutter/material.dart';

import '../../models/reward_marker.dart';

class RewardPreviewDialog extends StatelessWidget {
  const RewardPreviewDialog({
    super.key,
    required this.reward,
    required this.locationName,
    this.onCollect,
    this.isDemo = true,
    this.noteOverride,
  });

  final RewardMarker reward;
  final String locationName;
  final VoidCallback? onCollect;
  final bool isDemo;
  final String? noteOverride;

  @override
  Widget build(BuildContext context) {
    final isExp = reward.type == RewardType.exp;

    return RewardDialogCard(
      heading: isExp ? 'Reward Nearby!' : 'Voucher Nearby!',
      icon: isExp
          ? Icons.star_rounded
          : isDemo
          ? Icons.bolt_rounded
          : Icons.confirmation_number_outlined,
      colors: isExp
          ? const [Color(0xFFFFD83D), Color(0xFFFFAA00)]
          : const [Color(0xFF4A82F4), Color(0xFF3267D8)],
      title: isExp ? '${reward.expAmount} EXP Found' : reward.title,
      description: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: isDemo
                  ? 'You found a demo reward near '
                  : isExp
                  ? 'Great job exploring! You found a reward at '
                  : 'Great job exploring! You found a voucher at ',
            ),
            TextSpan(
              text: locationName,
              style: const TextStyle(
                color: Color(0xFF3267D8),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: isDemo ? '.' : ' area.'),
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
          noteOverride ??
          (onCollect == null
              ? 'Preview only. Collection is not enabled yet.'
              : isDemo
              ? 'Demo collection only. No real EXP or voucher is issued.\n'
                    'Your location and reward availability will be checked again.'
              : 'Your location and reward availability will be checked again.'),
      buttonLabel: isDemo && onCollect != null
          ? 'COLLECT DEMO REWARD'
          : 'COLLECT REWARD',
      buttonColor: const Color(0xFF3267D8),
      onPressed: onCollect,
    );
  }
}

// Shared presentation used by both reward preview and out-of-range dialogs.
class RewardDialogCard extends StatelessWidget {
  const RewardDialogCard({
    super.key,
    required this.heading,
    required this.icon,
    required this.colors,
    required this.title,
    required this.description,
    required this.note,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onPressed,
    this.locked = false,
  });

  final String heading;
  final IconData icon;
  final List<Color> colors;
  final String title;
  final Widget description;
  final String note;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback? onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 76,
                      color: locked ? Colors.white54 : Colors.white,
                    ),
                    if (locked)
                      const Icon(
                        Icons.lock_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              description,
              const SizedBox(height: 20),
              Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: buttonColor.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: onPressed == null ? 0 : 5,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
