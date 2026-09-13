import 'dart:async';
import 'package:flutter/material.dart';
import '../core/password_field.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_location.dart';
import '../core/localquest_widgets.dart';
import '../core/input_validators.dart';
import '../models/localquest_models.dart';
import '../services/localquest_services.dart';
import '../services/biometric_auth_service.dart';

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
              autovalidateMode: AutovalidateMode.disabled,
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
                          key: const Key('login_email_field'),
                          controller: _email,
                          label: 'Email address or username',
                          hint: 'you@example.com or @username',
                          keyboardType: TextInputType.text,
                          validator: _validateLoginIdentifier,
                        ),
                        const SizedBox(height: 16),
                        LqField(
                          key: const Key('login_password_field'),
                          controller: _password,
                          label: 'Password',
                          obscureText: true,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Password is required.' : null,
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

  String? _validateLoginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    final clean = value.trim();
    final hasAt = clean.contains('@');
    final startsWithAt = clean.startsWith('@');

    // If it has '@' anywhere other than the leading char, the user is typing an email.
    if (!startsWithAt && hasAt) {
      if (!LqInputValidators.emailPattern.hasMatch(clean)) {
        return 'Enter a valid email address (e.g. name@example.com).';
      }
      return null;
    }

    // Otherwise, validate as a username format (@... or without @)
    final usernamePart = startsWithAt ? clean.substring(1) : clean;
    if (usernamePart.isEmpty) {
      return 'Enter a valid email address or username.';
    }
    if (usernamePart.contains(' ') ||
        !LqInputValidators.usernamePattern.hasMatch(usernamePart)) {
      return 'Enter a valid email address or username.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final profile = await AuthService.instance.signIn(
        email: _email.text,
        password: _password.text,
        expectedRole: widget.role,
      );
      BiometricAuthService.instance.markJustAuthenticated();
      await BiometricAuthService.instance.saveLastUser(
        email: profile.email,
        role: widget.role.name,
        username: profile.username,
      );
      await AccountIdentifierCache.cache(
        username: profile.username,
        email: profile.email,
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
  final _postcode = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 2;
  bool _busy = false;
  LqLocation? _businessLocation;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameError;

  Timer? _emailDebounce;
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable;
  String? _emailError;

  bool get merchant => widget.role == AccountRole.merchant;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    for (final controller in [
      _name,
      _username,
      _phone,
      _birthday,
      _category,
      _address,
      _postcode,
      _city,
      _state,
      _email,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final formatError = LqInputValidators.validateUsernameFormat(value);
    if (formatError != null) {
      if (_usernameError != null || _isUsernameAvailable != null) {
        setState(() {
          _usernameError = null;
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
        });
      }
      return;
    }
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 300), () async {
      final available =
          await LqInputValidators.checkUsernameAvailability(value);
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = available;
        _usernameError = available ? null : 'Username is already taken.';
      });
      _form.currentState?.validate();
    });
  }

  void _onEmailChanged(String value) {
    _emailDebounce?.cancel();
    final formatError = LqInputValidators.validateEmailFormat(value);
    if (formatError != null) {
      if (_emailError != null || _isEmailAvailable != null) {
        setState(() {
          _emailError = null;
          _isCheckingEmail = false;
          _isEmailAvailable = null;
        });
      }
      return;
    }
    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });
    _emailDebounce = Timer(const Duration(milliseconds: 300), () async {
      final available = await LqInputValidators.checkEmailAvailability(value);
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        _isEmailAvailable = available;
        _emailError =
            available ? null : 'An account with this email already exists.';
      });
      _form.currentState?.validate();
    });
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
              autovalidateMode: AutovalidateMode.disabled,
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
          label: 'Street address',
          initialLocation: _businessLocation,
          onLocationChanged: (value) =>
              setState(() => _businessLocation = value),
          onAddressComponentsChanged: (components) {
            setState(() {
              if (components.postcode.isNotEmpty) {
                _postcode.text = components.postcode;
              }
              if (components.city.isNotEmpty) {
                _city.text = components.city;
              }
              if (components.state.isNotEmpty) {
                _state.text = components.state;
              }
            });
          },
          validator: LqInputValidators.validateAddressFormat,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LqField(
                controller: _postcode,
                label: 'Postcode',
                hint: 'e.g. 13500',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required.';
                  if (!RegExp(r'^\d{5}$').hasMatch(v.trim())) {
                    return '5-digit code.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LqField(
                controller: _city,
                label: 'Area / city',
                hint: 'e.g. Permatang Pauh',
                validator: _required,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LqDropdownField(
          value: _state.text.isEmpty ? null : _state.text,
          label: 'State',
          items: MalaysianAddressComponents.malaysianStates,
          onChanged: (value) => setState(() => _state.text = value ?? ''),
          validator: _required,
        ),
        if (_businessLocation != null &&
            LqInputValidators.isWithinMalaysia(
              _businessLocation!.latitude,
              _businessLocation!.longitude,
            )) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Color(0xFF42723B)),
              SizedBox(width: 4),
              Text(
                'Verified Malaysian location',
                style: TextStyle(
                  color: Color(0xFF42723B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ] else ...[
        LqField(
          controller: _username,
          label: 'Username',
          hint: '@aisharoams',
          onChanged: _onUsernameChanged,
          suffixWidget: _isCheckingUsername
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_isUsernameAvailable == true
                    ? const Icon(Icons.check_circle, color: Color(0xFF42723B))
                    : (_usernameError != null
                          ? const Icon(Icons.error_outline, color: Colors.red)
                          : null)),
          validator: (v) =>
              LqInputValidators.validateUsernameFormat(v) ?? _usernameError,
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
        onChanged: _onEmailChanged,
        suffixWidget: _isCheckingEmail
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (_isEmailAvailable == true
                  ? const Icon(Icons.check_circle, color: Color(0xFF42723B))
                  : (_emailError != null
                        ? const Icon(Icons.error_outline, color: Colors.red)
                        : null)),
        validator: (v) =>
            LqInputValidators.validateEmailFormat(v) ?? _emailError,
      ),
      const SizedBox(height: 16),
      LqNewPasswordField(
        key: const Key('signup_password_field'),
        controller: _password,
      ),
      const SizedBox(height: 16),
      LqField(
        key: const Key('signup_confirm_password_field'),
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
          area: _city.text,
          postcode: _postcode.text,
          state: _state.text,
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
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _submitted = false;

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
            child: Form(
              key: _form,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
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
                          key: const Key('forgot_password_email_field'),
                          controller: _email,
                          label: 'Email address',
                          hint: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: LqInputValidators.validateEmailFormat,
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
          ),
        ],
      ),
    ),
  );

  Future<void> _send() async {
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
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
