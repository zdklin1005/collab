import 'package:flutter/material.dart';
import 'localquest_theme.dart';
import 'password_policy.dart';

class LqNewPasswordField extends StatefulWidget {
  const LqNewPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
  });
  final TextEditingController controller;
  final String label;
  @override
  State<LqNewPasswordField> createState() => _LqNewPasswordFieldState();
}

class _LqNewPasswordFieldState extends State<LqNewPasswordField> {
  bool _hidden = true;
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: widget.controller,
    builder: (context, value, _) {
      final text = value.text;
      final score = PasswordPolicy.score(text);
      final label = ['Not entered', 'Weak', 'Fair', 'Good', 'Strong'][score];
      final color = [
        LqColors.muted,
        LqColors.danger,
        Colors.orange,
        LqColors.primary,
        LqColors.success,
      ][score];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: PasswordPolicy.validate,
            decoration: InputDecoration(
              labelText: widget.label,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Password strength: $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Estimated password strength',
            value: label,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score / 4,
                minHeight: 6,
                color: color,
                backgroundColor: LqColors.line,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _check(
            '15–128 characters',
            text.runes.length >= 15 && text.runes.length <= 128,
          ),
          _check(
            'No obvious common or repeated pattern',
            text.isNotEmpty && !PasswordPolicy.isObvious(text),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try several unrelated words. Spaces are allowed. Strength is an estimate; use a unique password.',
            style: TextStyle(fontSize: 11, color: LqColors.muted, height: 1.4),
          ),
        ],
      );
    },
  );
  Widget _check(String label, bool met) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 15,
          color: met ? LqColors.success : LqColors.muted,
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
