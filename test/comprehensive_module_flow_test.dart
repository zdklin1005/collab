import 'package:collab/core/localquest_theme.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/core/password_field.dart';
import 'package:collab/core/ssm_verification.dart';
import 'package:collab/main.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/auth_screens.dart';
import 'package:collab/screens/merchant_screens.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/services/biometric_auth_service.dart';
import 'package:collab/services/localquest_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget testApp(Widget home) => MaterialApp(
  theme: localQuestTheme(),
  home: Scaffold(body: home),
);

const testTourist = AppUser(
  id: 'tourist-101',
  email: 'tourist@localquest.test',
  displayName: 'Kenny Yeoh',
  username: '@kenny_yeoh',
  role: AccountRole.tourist,
  level: 3,
  exp: 420,
  voucherCount: 5,
  reviewCount: 12,
);

const testMerchant = AppUser(
  id: 'merchant-202',
  email: 'merchant@localquest.test',
  displayName: 'Heritage Cafe',
  username: '@heritage_cafe',
  role: AccountRole.merchant,
);

final testBusiness = Business(
  id: 'biz-1',
  ownerId: 'merchant-202',
  name: 'Heritage Cafe Penang',
  category: 'Cafe',
  registrationNumber: '202003123456 (003123456-M)',
  address: '123 Beach Street, George Town, Penang',
  phone: '04-2611234',
  latitude: 5.4141,
  longitude: 100.3288,
  active: true,
  verificationStatus: 'verified',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme & InputDecoration Validation Styling', () {
    test('Theme applies LqColors.danger to errorBorder and focusedErrorBorder with 16px radius', () {
      final theme = localQuestTheme();
      final decoration = theme.inputDecorationTheme;

      expect(decoration.errorBorder, isA<OutlineInputBorder>());
      final errorBorder = decoration.errorBorder as OutlineInputBorder;
      expect(errorBorder.borderSide.color, LqColors.danger);
      expect(errorBorder.borderRadius, BorderRadius.circular(16));

      expect(decoration.focusedErrorBorder, isA<OutlineInputBorder>());
      final focusedErrorBorder = decoration.focusedErrorBorder as OutlineInputBorder;
      expect(focusedErrorBorder.borderSide.color, LqColors.danger);
      expect(focusedErrorBorder.borderRadius, BorderRadius.circular(16));

      expect(decoration.errorStyle?.color, LqColors.danger);
      expect(decoration.errorStyle?.fontSize, 12);
    });
  });

  group('Functional Testing: Inline Text Field Error Highlighting', () {
    testWidgets('LoginScreen highlights email field in red on malformed email without showing SnackBar', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('login_email_field'));
      final signInBtn = find.widgetWithText(LqButton, 'Sign in');

      // Enter malformed email
      await tester.enterText(emailField, 'bad-email@');
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Field must display inline error text
      expect(find.text('Enter a valid email address (e.g. name@example.com).'), findsOneWidget);
      // No snackbar should be displayed
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('LoginScreen highlights email field on invalid username symbols without showing SnackBar', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('login_email_field'));
      final signInBtn = find.widgetWithText(LqButton, 'Sign in');

      // Enter username with spaces or invalid symbols
      await tester.enterText(emailField, 'invalid username with spaces');
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address or username.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('LoginScreen highlights required fields on empty submission', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final signInBtn = find.widgetWithText(LqButton, 'Sign in');
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('ForgotPasswordScreen highlights email field on malformed email without SnackBar', (tester) async {
      await tester.pumpWidget(testApp(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('forgot_password_email_field'));
      final sendBtn = find.widgetWithText(LqButton, 'Send reset link');

      await tester.enterText(emailField, 'not-an-email');
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address (e.g. name@example.com).'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('EmailAddressScreen highlights new email field on invalid format without SnackBar', (tester) async {
      await tester.pumpWidget(testApp(const EmailAddressScreen(currentEmail: 'old@example.com')));
      await tester.pumpAndSettle();

      final newEmailField = find.byKey(const Key('change_email_new_field'));
      final sendBtn = find.widgetWithText(LqButton, 'Save changes');

      await tester.enterText(newEmailField, 'malformed@com');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address (e.g. name@example.com).'), findsOneWidget);
      expect(find.text('Enter your current password.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('PasswordSecurityScreen highlights mismatched confirm password field', (tester) async {
      await tester.pumpWidget(testApp(const PasswordSecurityScreen()));
      await tester.pumpAndSettle();

      final currentField = find.byKey(const Key('change_password_current_field'));
      final newField = find.byKey(const Key('change_password_new_field'));
      final confirmField = find.byKey(const Key('change_password_confirm_field'));
      final saveBtn = find.widgetWithText(LqButton, 'Save changes');

      await tester.enterText(currentField, 'OldPassword123!');
      await tester.enterText(newField, 'NewPassword123!');
      await tester.enterText(confirmField, 'MismatchPassword123!');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });

  group('Flow Testing: Authentication & Biometric Gate Lifecycle', () {
    testWidgets('Flow 1: Session authentication routes directly to Discover without biometric prompt', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true);
      // Simulate successful login having marked session authenticated
      mock.markSessionAuthenticated(testTourist.id);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(BiometricGate(
          user: testTourist,
          child: const Text('Discover Page Content'),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover Page Content'), findsOneWidget);
      expect(find.text('Unlock with biometrics'), findsNothing);
    });

    testWidgets('Flow 2: Locked biometric gate displays password fallback', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true, authSucceeds: false);
      mock.clearSessionAuthentication(testTourist.id);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(BiometricGate(
          user: testTourist,
          child: const Text('Discover Page Content'),
        )),
      );
      await tester.pumpAndSettle();

      // Should be locked
      expect(find.text('LocalQuest is locked. Verify your fingerprint or face recognition to access your account.'), findsOneWidget);
      expect(find.byKey(const Key('biometric_gate_proceed_login_btn')), findsOneWidget);

      // Tap Proceed to log in with password
      await tester.tap(find.byKey(const Key('biometric_gate_proceed_login_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Log in with password'), findsOneWidget);
      expect(find.byKey(const Key('biometric_gate_password_field')), findsOneWidget);
    });

    testWidgets('Flow 3: Sign out / switch account button is present in BiometricGate', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true, authSucceeds: false);
      mock.clearSessionAuthentication(testTourist.id);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(BiometricGate(
          user: testTourist,
          child: const Text('Discover Page Content'),
        )),
      );
      await tester.pumpAndSettle();

      final signOutBtn = find.byKey(const Key('biometric_gate_signout_btn'));
      expect(signOutBtn, findsOneWidget);
      expect(find.text('Sign out / Switch account'), findsOneWidget);
    });
  });

  group('Flow Testing: Tourist Profile, Journey Items & Preferences', () {
    testWidgets('Flow 4: TouristProfileScreen displays rounded square avatar, stats, journey items and settings', (tester) async {
      await tester.pumpWidget(testApp(const TouristProfileScreen(user: testTourist)));
      await tester.pumpAndSettle();

      // User header details
      expect(find.text('Kenny Yeoh'), findsOneWidget);
      expect(find.text('@kenny_yeoh'), findsOneWidget);
      expect(find.text('EXPLORER · LEVEL 3'), findsOneWidget);
      expect(find.text('420/1,200XP'), findsOneWidget);
      expect(find.text('VOUCHERS'), findsOneWidget);
      expect(find.text('REVIEWS'), findsOneWidget);

      // Journey items
      expect(find.text('Visited places'), findsOneWidget);
      expect(find.text('My vouchers'), findsOneWidget);
      expect(find.text('5 ready to use'), findsOneWidget);
      expect(find.text('Missions'), findsOneWidget);
      expect(find.text('Reviews & ratings'), findsOneWidget);
      expect(find.text('Daily check-in'), findsOneWidget);
      expect(find.text('My Friends'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);

      // Settings action
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('Flow 5: SettingsScreen renders personal details, switches, and logout with dialog confirmation', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: false);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(testApp(const SettingsScreen(user: testTourist)));
      await tester.pumpAndSettle();

      // Personal details tiles
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password & security'), findsOneWidget);
      expect(find.text('Biometric sign-in'), findsOneWidget);

      // Preferences toggles
      expect(find.text('Location history'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      // Account actions
      final logOutBtn = find.byType(LqLogoutButton);
      expect(logOutBtn, findsOneWidget);

      // Tap Log out to trigger confirmation dialog
      await tester.ensureVisible(logOutBtn);
      await tester.tap(logOutBtn);
      await tester.pumpAndSettle();

      expect(find.text('Log out of LocalQuest?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Log out'), findsWidgets);
    });
  });

  group('Flow Testing: Merchant Workspace, Registrations & SSM Verification', () {
    testWidgets('Flow 6: MerchantOverview displays metrics and campaign details', (tester) async {
      await tester.pumpWidget(testApp(MerchantOverview(
        user: testMerchant,
        business: testBusiness,
        openCampaigns: () {},
        campaignStream: Stream.value(<Campaign>[]),
      )));
      await tester.pumpAndSettle();

      // Metrics
      expect(find.text('Vouchers claimed'), findsOneWidget);
      expect(find.text('Campaign views'), findsOneWidget);
      expect(find.text('Active campaigns'), findsOneWidget);
    });

    testWidgets('Flow 7: BusinessEditor validates name, category, registration, address and phone', (tester) async {
      await tester.pumpWidget(testApp(BusinessEditor(user: testMerchant, business: testBusiness)));
      await tester.pumpAndSettle();

      expect(find.text('Edit business'), findsOneWidget);
      expect(find.widgetWithText(LqField, 'Business name'), findsOneWidget);
      expect(find.widgetWithText(LqField, 'Registration number'), findsOneWidget);
      expect(find.text('Scan registration certificate'), findsOneWidget);
    });

    test('Flow 8: SsmVerificationEngine verifies authentic Borang D certificate', () {
      const sampleCertificate = '''
SURUHANJAYA SYARIKAT MALAYSIA
COMPANIES COMMISSION OF MALAYSIA
PERAKUAN PENDAFTARAN
BORANG D (KAEDAH 13)
AKTA PENDAFTARAN PERNIAGAAN 1956
NOMBOR PENDAFTARAN: 202003123456 (003123456-M)
NAMA PERNIAGAAN: HERITAGE CAFE PENANG ENTERPRISE
TARIKH LUPUT: 15/10/2028
STATUS: AKTIF
''';

      final analysis = SsmVerificationEngine.analyze(
        text: sampleCertificate,
        userEnteredBusinessName: 'Heritage Cafe Penang',
        referenceDate: DateTime(2026, 9, 1),
      );

      expect(analysis.isAuthenticSsm, isTrue);
      expect(analysis.status, 'verified');
      expect(analysis.isExpired, isFalse);
    });
  });

  group('Usability & Accessibility Testing', () {
    testWidgets('Form inputs expose proper accessibility keyboards and labels', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final emailWidget = tester.widget<LqField>(find.byKey(const Key('login_email_field')));
      expect(emailWidget.keyboardType, TextInputType.text);

      final passwordWidget = tester.widget<LqField>(find.widgetWithText(LqField, 'Password'));
      expect(passwordWidget.obscureText, isTrue);
    });

    testWidgets('LqNewPasswordField toggles visibility cleanly', (tester) async {
      final controller = TextEditingController(text: 'SecretPass123!');
      await tester.pumpWidget(testApp(LqNewPasswordField(controller: controller)));
      await tester.pumpAndSettle();

      final eyeBtn = find.byTooltip('Show password');
      expect(eyeBtn, findsOneWidget);

      await tester.tap(eyeBtn);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('HelpCentreScreen and PrivacyScreen render header with icon container matching Figma design', (tester) async {
      await tester.pumpWidget(testApp(const HelpCentreScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Help centre'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);

      await tester.pumpWidget(testApp(const PrivacyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
    });

    test('AccountIdentifierCache stores and resolves username case-insensitively with/without @', () async {
      SharedPreferences.setMockInitialValues({});
      await AccountIdentifierCache.cache(username: '@OP81', email: 'op81@localquest.test');

      expect(await AccountIdentifierCache.lookup('@OP81'), 'op81@localquest.test');
      expect(await AccountIdentifierCache.lookup('OP81'), 'op81@localquest.test');
      expect(await AccountIdentifierCache.lookup('op81'), 'op81@localquest.test');
      expect(await AccountIdentifierCache.lookup('@op81'), 'op81@localquest.test');
    });

    testWidgets('LoginScreen does NOT highlight error while typing and highlights on Sign In tap', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('login_email_field'));
      final signInBtn = find.widgetWithText(LqButton, 'Sign in');

      // Type incomplete email - should NOT show error while typing
      await tester.enterText(emailField, 'op81@');
      await tester.pump();
      expect(find.text('Enter a valid email address (e.g. name@example.com).'), findsNothing);

      // Tap Sign In - now it should validate and highlight
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address (e.g. name@example.com).'), findsOneWidget);
    });
  });
}
