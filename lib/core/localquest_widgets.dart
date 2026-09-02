import 'package:flutter/material.dart';

import 'localquest_theme.dart';

class LqPage extends StatelessWidget {
  const LqPage({super.key, required this.child, this.bottomNavigationBar});

  final Widget child;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: bottomNavigationBar != null,
    backgroundColor: LqColors.background,
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child,
        ),
      ),
    ),
  );
}

class LqLogo extends StatelessWidget {
  const LqLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: LqColors.primary,
      borderRadius: BorderRadius.circular(size * .36),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3D3267D4),
          blurRadius: 14,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Text(
      'L',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: size * .42,
      ),
    ),
  );
}

class LqTitleBlock extends StatelessWidget {
  const LqTitleBlock({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(eyebrow.toUpperCase(), style: monoLabel),
      const SizedBox(height: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 32,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(
          subtitle!,
          style: const TextStyle(color: LqColors.muted, height: 1.45),
        ),
      ],
    ],
  );
}

class LqCard extends StatelessWidget {
  const LqCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
    this.dashed = true,
    this.borderColor = LqColors.primary,
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final bool dashed;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: dashed
        ? const _DashedRoundedBorderPainter(
            color: borderColor,
            radius: 25,
            strokeWidth: 1.35,
          )
        : null,
    child: Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
        border: dashed
            ? null
            : Border.all(color: borderColor, width: 1.35),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10293C62),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    ),
  );
}

class LqDashedDivider extends StatelessWidget {
  const LqDashedDivider({super.key, this.vertical = false, this.color});
  final bool vertical;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedLinePainter(color ?? LqColors.primary, vertical),
    child: SizedBox(
      width: vertical ? 1.35 : double.infinity,
      height: vertical ? double.infinity : 1.35,
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color, this.vertical);
  final Color color;
  final bool vertical;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.35;
    final length = vertical ? size.height : size.width;
    for (double offset = 0; offset < length; offset += 6) {
      final end = (offset + 3.2).clamp(0, length).toDouble();
      canvas.drawLine(
        vertical ? Offset(0, offset) : Offset(offset, 0),
        vertical ? Offset(0, end) : Offset(end, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.vertical != vertical;
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 7) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + 3.8).clamp(0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}

class LqButton extends StatelessWidget {
  const LqButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: destructive ? LqColors.danger : LqColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 5,
        shadowColor: destructive
            ? LqColors.danger.withValues(alpha: .25)
            : LqColors.primary.withValues(alpha: .3),
      ),
    ),
  );
}

class LqBackButton extends StatelessWidget {
  const LqBackButton({super.key, this.label = 'Back'});
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => Navigator.maybePop(context),
    icon: const Icon(Icons.chevron_left, size: 18),
    label: Text(
      label.toUpperCase(),
      style: monoLabel.copyWith(color: LqColors.primary, fontSize: 11),
    ),
  );
}

class LqField extends StatelessWidget {
  const LqField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
    readOnly: readOnly,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
    ),
  );
}

const lqBusinessCategories = <String>[
  'Cafe',
  'Restaurant',
  'Accommodation',
  'Attraction',
  'Retail',
  'Artisan',
  'Tour & activity',
  'Other',
];

class LqDropdownField extends StatelessWidget {
  const LqDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value != null && items.contains(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: onChanged,
    validator: validator,
  );
}

class LqFloatingNavBar extends StatelessWidget {
  const LqFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.profileInitials,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<(IconData, String)> items;
  final String profileInitials;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.only(bottom: 12),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white,
            elevation: 14,
            shadowColor: const Color(0x66293C62),
            borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(2, (index) => _navItem(index)),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Material(
            color: Colors.white,
            elevation: 14,
            shadowColor: const Color(0x66293C62),
            borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () => onSelected(2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    color: selectedIndex == 2
                        ? LqColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFE4C8B7),
                        child: Text(
                          profileInitials,
                          style: const TextStyle(
                            color: Color(0xFF573725),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -2),
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            color: selectedIndex == 2
                                ? Colors.white
                                : LqColors.ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _navItem(int index) {
    final selected = index == selectedIndex;
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => onSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 76,
        height: 52,
        decoration: BoxDecoration(
          color: selected ? LqColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(items[index].$1, size: 19, color: LqColors.ink),
            const SizedBox(height: 2),
            Text(
              items[index].$2,
              style: const TextStyle(
                color: LqColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LqLogoutButton extends StatelessWidget {
  const LqLogoutButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onPressed,
    child: LqCard(
      color: LqColors.danger.withValues(alpha: .05),
      borderColor: LqColors.danger,
      padding: EdgeInsets.zero,
      child: const SizedBox(
        height: 49,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 17, color: LqColors.danger),
            SizedBox(width: 8),
            Text(
              'Log out',
              style: TextStyle(
                color: LqColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String initialsFor(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'LQ';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length.clamp(0, 2))
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

void showLqMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? LqColors.danger : LqColors.ink,
    ),
  );
}

Future<void> confirmLqSignOut(
  BuildContext context,
  Future<void> Function() signOut,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: LqCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFF8EDEF),
              foregroundColor: LqColors.danger,
              child: Icon(Icons.lock_outline),
            ),
            const SizedBox(height: 18),
            Text('ACCOUNT SESSION', style: monoLabel),
            const SizedBox(height: 6),
            const Text(
              'Log out of LocalQuest?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will need to sign in again to access your account.',
              style: TextStyle(color: LqColors.muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.logout, size: 17),
                    label: const Text('Log out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: LqColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed == true) await signOut();
}
