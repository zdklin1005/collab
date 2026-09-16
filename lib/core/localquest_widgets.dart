import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'localquest_theme.dart';

class LqPage extends StatelessWidget {
  const LqPage({super.key, required this.child, this.bottomNavigationBar});

  final Widget child;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LqColors.background,
    body: Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
        if (bottomNavigationBar != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(ignoring: false, child: bottomNavigationBar!),
          ),
      ],
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
      borderRadius: BorderRadius.circular(size * .24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3D136AD4),
          blurRadius: 14,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: LqColors.primary,
          alignment: Alignment.center,
          child: Text(
            'LQ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * .38,
            ),
          ),
        ),
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
    this.icon,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textColumn = Column(
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

    if (icon == null) return textColumn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFDCE8FF),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: LqColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: textColumn),
      ],
    );
  }
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
        ? _DashedRoundedBorderPainter(
            color: borderColor,
            radius: 25,
            strokeWidth: 1.35,
          )
        : null,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10293C62),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: dashed
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 1.35),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
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

class LqTierBadge extends StatelessWidget {
  const LqTierBadge({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const _DashedRoundedBorderPainter(
      color: LqColors.primary,
      radius: 999,
      strokeWidth: 1,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'EXPLORER · LEVEL $level',
        maxLines: 1,
        style: monoLabel.copyWith(
          color: LqColors.primary,
          fontSize: 8.5,
          height: 1.5,
          letterSpacing: .85,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

class LqSegmentedControl<T> extends StatelessWidget {
  const LqSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const _DashedRoundedBorderPainter(
      color: LqColors.primary,
      radius: 999,
      strokeWidth: 1.35,
    ),
    child: Container(
      padding: const EdgeInsets.all(5.35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = segment.$1 == selected;
          return Flexible(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(segment.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? LqColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x333267D4),
                              blurRadius: 7,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    segment.$2,
                    style: TextStyle(
                      color: isSelected ? Colors.white : LqColors.muted,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
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

class LqDashedBorderPainter extends CustomPainter {
  const LqDashedBorderPainter({
    required this.color,
    this.radius = 16,
    this.borderRadius,
    this.strokeWidth = 1.35,
    this.dashLength = 3.8,
    this.gapLength = 3.2,
  });

  final Color color;
  final double radius;
  final BorderRadius? borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius != null
        ? borderRadius!.toRRect(Offset.zero & size)
        : RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final step = dashLength + gapLength;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += step) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dashLength).clamp(0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LqDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}

typedef _DashedRoundedBorderPainter = LqDashedBorderPainter;

class LqButton extends StatelessWidget {
  const LqButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.destructive = false,
    this.pill = false,
  });

  const LqButton.pill({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.destructive = false,
  }) : icon = null, pill = true;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool destructive;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    if (pill) {
      return FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE8EEFA),
          foregroundColor: const Color(0xFF2563EB),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          minimumSize: const Size(0, 42),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2563EB),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF2563EB),
                ),
              ),
      );
    }

    return SizedBox(
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
}

class LqGoogleButton extends StatelessWidget {
  const LqGoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const String googleSvg = '''
<svg viewBox="0 0 24 24" width="24" height="24" xmlns="http://www.w3.org/2000/svg">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: LqColors.ink,
          side: const BorderSide(color: LqColors.line, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.string(
                    googleSvg,
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: LqColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class LqGoogleLogo extends StatelessWidget {
  const LqGoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      LqGoogleButton.googleSvg,
      width: size,
      height: size,
    );
  }
}

class LqSpotifyLogo extends StatelessWidget {
  const LqSpotifyLogo({super.key, this.size = 20});
  final double size;

  static const String spotifySvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="12" fill="#1DB954"/>
  <path d="M17.9 10.39c-3.6-2.14-9.52-2.34-12.98-1.29-.55.17-1.14-.14-1.3-.69-.17-.55.14-1.14.69-1.3 4-1.21 10.54-.98 14.7 1.49.5.3.66.94.36 1.44-.29.49-.93.65-1.47.35zm-.13 3.25c-.26.42-.81.55-1.23.29-3.03-1.86-7.65-2.4-11.23-1.31-.48.14-.99-.13-1.13-.61-.14-.48.13-.99.61-1.13 4.1-1.24 9.2-.64 12.69 1.51.42.27.56.81.29 1.25zm-1.42 3.15c-.21.35-.67.46-1.02.25-2.65-1.62-5.98-1.98-9.91-1.09-.4.09-.8-.16-.89-.56-.09-.4.16-.8.56-.89 4.31-.98 8-.57 10.99 1.26.35.21.46.67.27 1.03z" fill="#000000"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      spotifySvg,
      width: size,
      height: size,
    );
  }
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

class LqField extends StatefulWidget {
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
    this.suffixWidget,
    this.onChanged,
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
  final Widget? suffixWidget;
  final ValueChanged<String>? onChanged;

  @override
  State<LqField> createState() => _LqFieldState();
}

class _LqFieldState extends State<LqField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant LqField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffix = widget.suffixWidget;
    if (suffix == null && widget.suffixIcon != null) {
      suffix = Icon(widget.suffixIcon);
    } else if (suffix == null && widget.obscureText) {
      suffix = IconButton(
        tooltip: _obscured ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: LqColors.muted,
          size: 20,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      maxLines: widget.maxLines,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: suffix,
      ),
    );
  }
}

const lqBusinessCategories = <String>[
  'Cafe',
  'Restaurant',
  'Food & Beverage',
  'Accommodation',
  'Attraction',
  'Retail',
  'Artisan',
  'Tour & activity',
  'Other',
];

/// Business categories that require Halal & dietary certification declarations.
const lqDietaryCategories = <String>[
  'Cafe',
  'Restaurant',
  'Food & Beverage',
];

/// Returns whether the provided category represents a food & beverage or dining
/// business that requires Halal & dietary certification.
bool lqIsDietaryCategory(String? category) {
  if (category == null || category.trim().isEmpty) return false;
  final cat = category.trim().toLowerCase();
  return cat == 'cafe' ||
      cat == 'restaurant' ||
      cat == 'food & beverage' ||
      cat.contains('food') ||
      cat.contains('dining') ||
      cat.contains('beverage') ||
      cat.contains('cafe') ||
      cat.contains('coffee') ||
      cat.contains('restaurant') ||
      cat.contains('bakery') ||
      cat.contains('dessert') ||
      cat.contains('eatery') ||
      cat.contains('bistro');
}

const lqDietaryStatuses = <String>[
  'Halal Certified',
  'Muslim-Friendly / Pork-Free',
  'Vegetarian-Friendly',
  'Non-Halal',
  'Not Applicable',
];

class LqDropdownField extends FormField<String> {
  LqDropdownField({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.validator,
  }) : super(
         key: key ?? ValueKey(label),
         initialValue: value != null && items.contains(value) ? value : null,
         builder: _buildDropdown,
       );
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  static Widget _buildDropdown(FormFieldState<String> state) {
    final field = state.widget as LqDropdownField;
    final selected = state.value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final value = await showLqSelectionSheet<String>(
          state.context,
          title: field.label,
          selected: selected,
          options: field.items.map((item) => (item, item)).toList(),
        );
        if (value == null) return;
        state.didChange(value);
        field.onChanged(value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          InputDecorator(
            decoration: InputDecoration(
              errorText: state.errorText,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: LqColors.primary,
              ),
            ),
            child: Text(
              selected ?? 'Choose ${field.label.toLowerCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected == null ? LqColors.muted : LqColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> showLqSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
    ),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
    decoration: const BoxDecoration(
      color: LqColors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: LqColors.line,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: LqColors.primarySoft,
              foregroundColor: LqColors.primary,
              child: Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LOCALQUEST SELECTOR', style: monoLabel),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Flexible(
          child: LqCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) =>
                  const LqDashedDivider(color: LqColors.line),
              itemBuilder: (context, index) {
                final option = options[index];
                final active = option.$1 == selected;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: active ? LqColors.primarySoft : null,
                  title: Text(
                    option.$2,
                    style: TextStyle(
                      color: active ? LqColors.primaryDark : LqColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: active
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: LqColors.primary,
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: LqColors.muted,
                        ),
                  onTap: () => Navigator.pop(sheetContext, option.$1),
                );
              },
            ),
          ),
        ),
      ],
    ),
  ),
);

Future<DateTime?> showLqDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Choose a date',
}) {
  var selected = initialDate;
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: LqCard(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: LqColors.primarySoft,
                        foregroundColor: LqColors.primary,
                        child: Icon(Icons.calendar_month_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LOCALQUEST CALENDAR', style: monoLabel),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: LqColors.primary,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: LqColors.ink,
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      dayShape: const WidgetStatePropertyAll(CircleBorder()),
                      todayBorder: const BorderSide(color: LqColors.primary),
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: selected,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    onDateChanged: (value) =>
                        setDialogState(() => selected = value),
                  ),
                ),
                const LqDashedDivider(color: LqColors.line),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, selected),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Choose date'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LqStatusPill extends StatelessWidget {
  const LqStatusPill({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF46815B) : const Color(0xFF7B8492);
    final background = active
        ? const Color(0xFFE4F2DF)
        : const Color(0xFFEEF0F4);
    return CustomPaint(
      foregroundPainter: _DashedRoundedBorderPainter(
        color: color,
        radius: 999,
        strokeWidth: 1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 10,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

enum LqAvatarShape { circle, roundedSquare }

/// Shared profile image with an initials fallback for absent or broken photos.
class LqAvatar extends StatelessWidget {
  const LqAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.radius = 36,
    this.shape = LqAvatarShape.roundedSquare,
  });
  final String initials;
  final String? photoUrl;
  final double radius;
  final LqAvatarShape shape;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFE4C8B7),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: radius < 20 ? 10 : 18,
            color: const Color(0xFF573725),
          ),
        ),
      ),
    );
    final url = Uri.tryParse(photoUrl ?? '');
    final child = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: url?.scheme == 'https' && url!.host.isNotEmpty
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : fallback,
            )
          : fallback,
    );
    return Semantics(
      label: 'Profile picture',
      image: true,
      child: shape == LqAvatarShape.circle
          ? ClipOval(child: child)
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius * .45),
              child: child,
            ),
    );
  }
}

class LqFloatingNavBar extends StatelessWidget {
  const LqFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.profileInitials,
    this.profilePhotoUrl,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<(IconData, String)> items;
  final String profileInitials;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.only(bottom: 12),
    child: Center(
      heightFactor: 1,
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
                      LqAvatar(
                        radius: 15,
                        initials: profileInitials,
                        photoUrl: profilePhotoUrl,
                        shape: LqAvatarShape.circle,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Profile',
                        style: TextStyle(
                          color: selectedIndex == 2
                              ? Colors.white
                              : LqColors.ink,
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w800,
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
          color: selected ? LqColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              items[index].$1,
              size: 19,
              color: selected ? Colors.white : LqColors.ink,
            ),
            const SizedBox(height: 2),
            Text(
              items[index].$2,
              style: TextStyle(
                color: selected ? Colors.white : LqColors.ink,
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
  if (confirmed != true) return;
  await signOut();
  if (context.mounted) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }
}
