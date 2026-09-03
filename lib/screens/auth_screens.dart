import 'package:flutter/material.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_location.dart';
import '../core/localquest_widgets.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';

class AccountTypeScreen extends StatelessWidget {
  const AccountTypeScreen({super.key, this.registration = false});
  final bool registration;

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 68, 16, 32),
      child: Column(
        children: [
          const LqLogo(),
          const SizedBox(height: 24),
          Text(
            registration ? 'STEP 1 OF 3' : 'ONE ACCOUNT, TWO WAYS TO ROAM',
            style: monoLabel,
          ),
          const SizedBox(height: 10),
          const Text(
            'How will you use\nLocalQuest?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              height: 1.4,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your account type to continue.',
            style: TextStyle(color: LqColors.muted),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 264,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _RoleCard(
                    role: AccountRole.tourist,
                    icon: Icons.explore_outlined,
                    color: LqColors.primarySoft,
                    description:
                        'Discover places, collect rewards, and track your journey.',
                    onTap: () => _open(context, AccountRole.tourist),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleCard(
                    role: AccountRole.merchant,
                    icon: Icons.storefront_outlined,
                    color: LqColors.greenSoft,
                    description:
                        'Create campaigns, vouchers, and grow your local business.',
                    onTap: () => _open(context, AccountRole.merchant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                registration
                    ? 'Already have an account?'
                    : 'New to LocalQuest?',
                style: const TextStyle(color: LqColors.muted, fontSize: 12),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AccountTypeScreen(registration: !registration),
                  ),
                ),
                child: Text(registration ? 'Sign in' : 'Create an account'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _open(BuildContext context, AccountRole role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            registration ? SignupScreen(role: role) : LoginScreen(role: role),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
  });
  final AccountRole role;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(25),
    child: LqCard(
      dashed: false,
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 205),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: role == AccountRole.tourist
                    ? LqColors.primary
                    : const Color(0xFF42723B),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              role.label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LqColors.muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const Spacer(),
            const Row(
              children: [
                Flexible(
                  child: Text(
                    'Continue',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LqColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward, color: LqColors.primary, size: 13),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});
  final AccountRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Change account type'),
          const SizedBox(height: 14),
          LqCard(
            padding: EdgeInsets.zero,
            child: Form(
              key: _form,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      color: LqColors.primarySoft,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LqLogo(),
                        const SizedBox(height: 20),
                        Text(
                          '${widget.role.label.toUpperCase()} ACCOUNT',
                          style: monoLabel.copyWith(
                            color: LqColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Welcome back.',
                          style: TextStyle(
                            color: LqColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.role == AccountRole.tourist
                              ? 'Your passport is ready when you are.'
                              : 'Your business dashboard is ready.',
                          style: const TextStyle(color: LqColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        LqField(
                          controller: _email,
                          label: 'Email address',
                          hint: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        LqField(
                          controller: _password,
                          label: 'Password',
                          obscureText: true,
                          validator: _required,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        LqButton(
                          label: 'Sign in',
                          busy: _busy,
                          icon: Icons.login,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'New to LocalQuest?',
                              style: TextStyle(
                                color: LqColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SignupScreen(role: widget.role),
                                ),
                              ),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.signIn(
        email: _email.text,
        password: _password.text,
        expectedRole: widget.role,
      );
      if (mounted) {
        showLqMessage(context, 'Welcome back to LocalQuest!');
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on LocalQuestException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.role});
  final AccountRole role;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _birthday = TextEditingController();
  final _category = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 2;
  bool _busy = false;
  LqLocation? _businessLocation;

  bool get merchant => widget.role == AccountRole.merchant;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _phone,
      _birthday,
      _category,
      _address,
      _email,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Change account type'),
          const SizedBox(height: 12),
          LqCard(
            padding: EdgeInsets.zero,
            child: Form(
              key: _form,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LqLogo(),
                        const SizedBox(height: 18),
                        Text(
                          'STEP $_step OF 3 · ${widget.role.label.toUpperCase()} ACCOUNT',
                          style: monoLabel,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == 2
                              ? 'Tell us about you.'
                              : 'Start your journey.',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == 2
                              ? (merchant
                                    ? 'Tell us about the business you want to register.'
                                    : 'These details help make your LocalQuest profile yours.')
                              : (merchant
                                    ? 'Create one account for all your businesses.'
                                    : 'Create one account for every place you go.'),
                          style: const TextStyle(color: LqColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _step == 2 ? _detailsStep() : _credentialsStep(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _detailsStep() => Column(
    children: [
      LqField(
        controller: _name,
        label: merchant ? 'Business name' : 'Full name',
        validator: _required,
      ),
      const SizedBox(height: 16),
      if (merchant) ...[
        LqDropdownField(
          value: _category.text.isEmpty ? null : _category.text,
          label: 'Business category',
          items: lqBusinessCategories,
          onChanged: (value) => setState(() => _category.text = value ?? ''),
          validator: _required,
        ),
        const SizedBox(height: 16),
        LqAddressField(
          controller: _address,
          label: 'Primary business address',
          initialLocation: _businessLocation,
          onLocationChanged: (value) => _businessLocation = value,
          validator: _required,
        ),
      ] else ...[
        LqField(
          controller: _username,
          label: 'Username',
          hint: '@aisharoams',
          validator: _required,
        ),
        const SizedBox(height: 16),
        LqField(
          controller: _birthday,
          label: 'Birthday',
          hint: 'Choose date',
          readOnly: true,
          suffixIcon: Icons.calendar_month_outlined,
          onTap: _pickBirthday,
        ),
      ],
      const SizedBox(height: 16),
      LqField(
        controller: _phone,
        label: merchant ? 'Business phone' : 'Phone number',
        keyboardType: TextInputType.phone,
        validator: _required,
      ),
      const SizedBox(height: 24),
      LqButton(label: 'Continue', onPressed: _next),
    ],
  );

  Widget _credentialsStep() => Column(
    children: [
      LqField(
        controller: _email,
        label: 'Email address',
        keyboardType: TextInputType.emailAddress,
        validator: _required,
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _password,
        label: 'Password',
        obscureText: true,
        validator: _passwordValidator,
      ),
      const SizedBox(height: 16),
      LqField(
        controller: _confirm,
        label: 'Confirm password',
        obscureText: true,
        validator: (value) =>
            value != _password.text ? 'Passwords do not match.' : null,
      ),
      const SizedBox(height: 24),
      LqButton(
        label: 'Create account',
        busy: _busy,
        icon: Icons.person_add_alt_1,
        onPressed: _create,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() => _step = 2),
        child: const Text('Back to details'),
      ),
    ],
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
  String? _passwordValidator(String? value) =>
      value == null || value.length < 8 ? 'Use at least 8 characters.' : null;

  void _next() {
    if (_form.currentState!.validate()) setState(() => _step = 3);
  }

  Future<void> _pickBirthday() async {
    final current = _parseDate(_birthday.text);
    final chosen = await showLqDatePicker(
      context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      title: 'Select birthday',
    );
    if (chosen != null) {
      setState(
        () => _birthday.text =
            '${chosen.day.toString().padLeft(2, '0')}/${chosen.month.toString().padLeft(2, '0')}/${chosen.year}',
      );
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (merchant) {
        await AuthService.instance.registerMerchant(
          email: _email.text,
          password: _password.text,
          businessName: _name.text,
          category: _category.text,
          address: _address.text,
          phone: _phone.text,
          latitude: _businessLocation?.latitude,
          longitude: _businessLocation?.longitude,
        );
      } else {
        await AuthService.instance.registerTourist(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          username: _username.text,
          phone: _phone.text,
          birthday: _parseDate(_birthday.text),
        );
      }
      if (mounted) {
        showLqMessage(context, 'Your LocalQuest account has been created.');
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on LocalQuestException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DateTime? _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    return DateTime.tryParse(
      '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Back to sign in'),
          const SizedBox(height: 18),
          LqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: LqColors.primarySoft,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: LqColors.primary,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.lock_reset),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Reset your password',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enter the email linked to your LocalQuest account and we’ll send you a reset link.',
                        style: TextStyle(color: LqColors.muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      LqField(
                        controller: _email,
                        label: 'Email address',
                        hint: 'you@example.com',
                      ),
                      const SizedBox(height: 20),
                      LqButton(
                        label: 'Send reset link',
                        busy: _busy,
                        icon: Icons.send_outlined,
                        onPressed: _send,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'For security, reset links expire after 30 minutes.',
                        style: TextStyle(color: LqColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _send() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.sendPasswordReset(_email.text);
      if (mounted) showLqMessage(context, 'Password reset email sent.');
    } on LocalQuestException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
