import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/localquest_theme.dart';
import 'models/localquest_models.dart';
import 'screens/auth_screens.dart';
import 'screens/merchant_screens.dart';
import 'screens/tourist_screens.dart';
import 'services/localquest_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          return profile.role == AccountRole.merchant
              ? MerchantHome(user: profile)
              : TouristHome(user: profile);
        },
      );
    },
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'L',
            style: TextStyle(
              color: LqColors.primary,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 18),
          CircularProgressIndicator(),
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
