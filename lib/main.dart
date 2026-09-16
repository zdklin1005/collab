import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/localquest_widgets.dart';
import 'core/localquest_theme.dart';
import 'models/localquest_models.dart';
import 'screens/auth_screens.dart';
import 'screens/merchant_screens.dart';
import 'screens/tourist_screens.dart';
import 'services/biometric_auth_service.dart';
import 'services/in_app_notification_service.dart';
import 'services/localquest_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  Object? setupError;
  try {
    await Firebase.initializeApp();
  } catch (error) {
    setupError = error;
  }
  runApp(LocalQuestApp(setupError: setupError));
}

class LocalQuestApp extends StatelessWidget {
  const LocalQuestApp({super.key, this.setupError});
  final Object? setupError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LocalQuest',
    debugShowCheckedModeBanner: false,
    theme: localQuestTheme(),
    home: setupError == null
        ? const AuthGate()
        : FirebaseSetupScreen(error: setupError!),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: AuthService.instance.authChanges,
    builder: (context, authSnapshot) {
      if (authSnapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingScreen();
      }
      final firebaseUser = authSnapshot.data;
      if (firebaseUser == null) return const AccountTypeScreen();
      return StreamBuilder<AppUser>(
        stream: UserRepository.instance.watch(firebaseUser.uid),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScreen();
          }
          if (profileSnapshot.hasError || !profileSnapshot.hasData) {
            return _ProfileRecoveryScreen(
              onSignOut: AuthService.instance.signOut,
            );
          }
          final profile = profileSnapshot.data!;
          InAppNotificationService.instance.startListening(profile.id);
          final home = profile.role == AccountRole.merchant
              ? MerchantHome(user: profile)
              : TouristHome(user: profile);
          return BiometricGate(
            key: ValueKey('biometric_${profile.id}'),
            user: profile,
            onSignOut: () async {
              InAppNotificationService.instance.stopListening();
              await AuthService.instance.signOut();
            },
            child: home,
          );
        },
      );
    },
  );
}

class BiometricGate extends StatefulWidget {
  const BiometricGate({
    super.key,
    required this.user,
    required this.child,
    this.onSignOut,
  });

  final AppUser user;
  final Widget child;
  final Future<void> Function()? onSignOut;

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  bool _checked = false;
  bool _unlocked = false;
  bool _authenticating = false;
  DateTime? _pausedAt;

  /// Background timeout: if the app is exited / in the background for 2+ seconds,
  /// re-lock and require biometric authentication upon returning.
  static const backgroundLockDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountIdentifierCache.cache(
      username: widget.user.username,
      email: widget.user.email,
    );
    _checkBiometricRequirement();
  }

  @override
  void didUpdateWidget(covariant BiometricGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.id != oldWidget.user.id) {
      _checked = false;
      _unlocked = false;
      AccountIdentifierCache.cache(
        username: widget.user.username,
        email: widget.user.email,
      );
      _checkBiometricRequirement();
    } else if (!_unlocked) {
      if (BiometricAuthService.instance.isSessionAuthenticated(
            widget.user.id,
          ) ||
          BiometricAuthService.instance.consumeJustAuthenticated()) {
        setState(() {
          _checked = true;
          _unlocked = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_authenticating) {
        _pausedAt = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null && !_authenticating) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
        if (elapsed >= backgroundLockDuration) {
          _reLock();
        }
      }
    }
  }

  Future<void> _reLock() async {
    final supported = await BiometricAuthService.instance.isSupported();
    final enabled = await BiometricAuthService.instance.isEnabled(
      widget.user.id,
    );
    if (!supported || !enabled) return;

    BiometricAuthService.instance.clearSessionAuthentication(widget.user.id);
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      setState(() => _unlocked = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticate();
      });
    }
  }

  Future<void> _checkBiometricRequirement() async {
    if (_unlocked) {
      if (!_checked && mounted) {
        setState(() => _checked = true);
      }
      return;
    }

    if (BiometricAuthService.instance.isSessionAuthenticated(widget.user.id) ||
        BiometricAuthService.instance.consumeJustAuthenticated()) {
      if (mounted) {
        setState(() {
          _checked = true;
          _unlocked = true;
        });
      }
      return;
    }

    final supported = await BiometricAuthService.instance.isSupported();
    final enabled = await BiometricAuthService.instance.isEnabled(
      widget.user.id,
    );

    if (!supported || !enabled) {
      if (mounted) {
        setState(() {
          _checked = true;
          _unlocked = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _checked = true;
        _unlocked = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticate();
      });
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    try {
      final success = await BiometricAuthService.instance.authenticate(
        localizedReason: 'Scan fingerprint or face to unlock LocalQuest',
      );
      if (mounted && success) {
        BiometricAuthService.instance.markSessionAuthenticated(widget.user.id);
        setState(() => _unlocked = true);
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  void _showPasswordLoginModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => _PasswordUnlockSheet(
        user: widget.user,
        onUnlocked: () {
          Navigator.of(modalContext).pop();
          if (mounted) {
            setState(() => _unlocked = true);
            showLqMessage(context, 'Unlocked with password.');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const _LoadingScreen();
    }
    if (_unlocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F2),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: LqColors.primary,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332B50ED),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Welcome back,\n${widget.user.displayName.trim().split(' ').first}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: LqColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'LocalQuest is locked. Verify your fingerprint or face recognition to access your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: LqColors.muted,
                  ),
                ),
                const SizedBox(height: 36),
                LqButton(
                  key: const Key('biometric_gate_unlock_btn'),
                  label: _authenticating
                      ? 'Verifying...'
                      : 'Unlock with biometrics',
                  icon: Icons.fingerprint,
                  onPressed: _authenticating ? null : _authenticate,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('biometric_gate_proceed_login_btn'),
                  onPressed: _showPasswordLoginModal,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text(
                    'Proceed to log in with password',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: LqColors.primary,
                    side: const BorderSide(color: LqColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('biometric_gate_signout_btn'),
                  onPressed: () async {
                    await AccountIdentifierCache.cache(
                      username: widget.user.username,
                      email: widget.user.email,
                    );
                    if (widget.onSignOut != null) {
                      await widget.onSignOut!();
                    } else {
                      await AuthService.instance.signOut();
                    }
                  },
                  child: const Text(
                    'Sign out / Switch account',
                    style: TextStyle(
                      color: LqColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordUnlockSheet extends StatefulWidget {
  const _PasswordUnlockSheet({required this.user, required this.onUnlocked});

  final AppUser user;
  final VoidCallback onUnlocked;

  @override
  State<_PasswordUnlockSheet> createState() => _PasswordUnlockSheetState();
}

class _PasswordUnlockSheetState extends State<_PasswordUnlockSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(
        email: widget.user.email,
        password: _password.text,
        expectedRole: widget.user.role,
      );
      BiometricAuthService.instance.markJustAuthenticated();
      if (mounted) {
        widget.onUnlocked();
      }
    } on LocalQuestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not verify password. Please try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD2D6DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_outline,
                  color: LqColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log in with password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: LqColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: LqColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('biometric_gate_password_field'),
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your account password',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: LqColors.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                try {
                  await AuthService.instance.sendPasswordReset(
                    widget.user.email,
                  );
                  if (context.mounted) {
                    showLqMessage(
                      context,
                      'Password reset link sent to ${widget.user.email}.',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    showLqMessage(
                      context,
                      'Could not send reset email. Please try again.',
                      error: true,
                    );
                  }
                }
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LqButton(
            key: const Key('biometric_gate_password_submit_btn'),
            label: _busy ? 'Verifying...' : 'Sign in & Unlock',
            busy: _busy,
            icon: Icons.login,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LqLogo(size: 72),
          const SizedBox(height: 20),
          const Text(
            'LocalQuest',
            style: TextStyle(
              color: LqColors.primaryDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Authentic Local Experiences',
            style: TextStyle(
              color: LqColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: LqColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileRecoveryScreen extends StatelessWidget {
  const _ProfileRecoveryScreen({required this.onSignOut});
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: LqColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'We couldn’t load your LocalQuest profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Check your connection and Firebase database setup, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LqColors.muted),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onSignOut,
              child: const Text('Return to sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                color: LqColors.primary,
                size: 54,
              ),
              const SizedBox(height: 18),
              const Text(
                'LocalQuest needs its Firebase configuration.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Complete the Android app registration and place google-services.json in android/app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LqColors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: LqColors.danger, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
