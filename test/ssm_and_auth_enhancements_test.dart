import 'package:collab/core/input_validators.dart';
import 'package:collab/core/localquest_location.dart';
import 'package:collab/core/localquest_theme.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/core/ssm_verification.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/auth_screens.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/main.dart';
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
  id: 'tourist-1',
  email: 'tourist@localquest.test',
  displayName: 'Test Tourist',
  username: '@testtourist',
  role: AccountRole.tourist,
);

void main() {
  group('SsmVerificationEngine', () {
    test('authenticates valid modern Malaysian SSM certificate', () {
      const sampleCertificate = '''
SURUHANJAYA SYARIKAT MALAYSIA
COMPANIES COMMISSION OF MALAYSIA
PERAKUAN PENDAFTARAN
BORANG D (KAEDAH 13)
AKTA PENDAFTARAN PERNIAGAAN 1956
NOMBOR PENDAFTARAN: 202003123456 (003123456-M)
NAMA PERNIAGAAN: LOCALQUEST CAFE ENTERPRISE
TARIKH LUPUT: 15/10/2028
STATUS: AKTIF
''';

      final result = SsmVerificationEngine.analyze(
        text: sampleCertificate,
        userEnteredBusinessName: 'LocalQuest Cafe',
        referenceDate: DateTime(2026, 9, 1),
      );

      expect(result.isAuthenticSsm, isTrue);
      expect(result.status, 'verified');
      expect(result.isExpired, isFalse);
      expect(result.modernRegistrationNumber, '202003123456');
      expect(result.legacyRegistrationNumber, '003123456-M');
      expect(
        result.formattedRegistrationNumber,
        '202003123456 (003123456-M)',
      );
      expect(result.confidenceScore, greaterThanOrEqualTo(0.70));
    });

    test('detects and flags expired SSM certificate', () {
      const expiredCertificate = '''
SURUHANJAYA SYARIKAT MALAYSIA
PERAKUAN PENDAFTARAN BORANG D
NOMBOR PENDAFTARAN: 201901002233
NAMA PERNIAGAAN: OLD VINTAGE STORE
TARIKH LUPUT: 01/01/2024
''';

      final result = SsmVerificationEngine.analyze(
        text: expiredCertificate,
        userEnteredBusinessName: 'Old Vintage Store',
        referenceDate: DateTime(2026, 9, 1),
      );

      expect(result.isAuthenticSsm, isTrue);
      expect(result.isExpired, isTrue);
      expect(result.status, 'rejected');
      expect(result.statusExplanation, contains('expired'));
    });

    test('rejects non-SSM documents or random text', () {
      const receiptText = '''
GROCERY MART RECEIPT
Total: RM 45.00
Thank you for shopping!
Date: 10/05/2026
''';

      final result = SsmVerificationEngine.analyze(
        text: receiptText,
        userEnteredBusinessName: 'Grocery Mart',
      );

      expect(result.isAuthenticSsm, isFalse);
      expect(result.status, 'rejected');
      expect(result.confidenceScore, lessThan(0.50));
    });

    test('calculates business name similarity ignoring Malaysian suffixes', () {
      final sim1 = SsmVerificationEngine.calculateBusinessNameSimilarity(
        'Artisan Bakery Sdn Bhd',
        'Artisan Bakery',
      );
      expect(sim1, greaterThanOrEqualTo(0.85));

      final sim2 = SsmVerificationEngine.calculateBusinessNameSimilarity(
        'Kopitiam Heritage Enterprise',
        'Kopitiam Heritage',
      );
      expect(sim2, greaterThanOrEqualTo(0.85));

      final sim3 = SsmVerificationEngine.calculateBusinessNameSimilarity(
        'Ferrari Workshop',
        'Boutique Clothing',
      );
      expect(sim3, lessThan(0.30));
    });

    test('authenticates Borang E renewal certificate with legacy number and OCR typos (Scribd sample)', () {
      const scribdSample = '''
sURUHANNYAAREKATMAYSTA
PERAKUAN PEMBAHARUAN PENDAFTARAN
AKTA PENDAFTARAN PERNIA GAAN 1956
BORANG E (KAEDAH 13)
001772726-T
''';
      final result = SsmVerificationEngine.analyze(
        text: scribdSample,
        referenceDate: DateTime(2026, 9, 1),
      );
      expect(result.isAuthenticSsm, isTrue);
      expect(result.status, 'verified');
      expect(result.legacyRegistrationNumber, '001772726-T');
    });
  });

  group('LqInputValidators', () {
    test('validates username format strictly', () {
      expect(LqInputValidators.validateUsernameFormat('aisha'), isNull);
      expect(LqInputValidators.validateUsernameFormat('@aisharoams'), isNull);
      expect(LqInputValidators.validateUsernameFormat('user_123'), isNull);

      expect(
        LqInputValidators.validateUsernameFormat('ab'),
        contains('at least 3 characters'),
      );
      expect(
        LqInputValidators.validateUsernameFormat('user@invalid!'),
        contains('Only letters, numbers, and underscores'),
      );
      expect(
        LqInputValidators.validateUsernameFormat(''),
        contains('required'),
      );
    });

    test('validates RFC-compliant email formats', () {
      expect(
        LqInputValidators.validateEmailFormat('test@localquest.my'),
        isNull,
      );
      expect(
        LqInputValidators.validateEmailFormat('kenny.yeoh@gmail.com'),
        isNull,
      );

      expect(
        LqInputValidators.validateEmailFormat('invalid-email'),
        contains('valid email'),
      );
      expect(
        LqInputValidators.validateEmailFormat('user@domain'),
        contains('valid email'),
      );
      expect(
        LqInputValidators.validateEmailFormat('@domain.com'),
        contains('valid email'),
      );
      expect(LqInputValidators.validateEmailFormat(''), contains('required'));
    });

    test('validates Malaysian geographic boundary coordinates', () {
      // Kuala Lumpur
      expect(LqInputValidators.isWithinMalaysia(3.1390, 101.6869), isTrue);
      // George Town, Penang
      expect(LqInputValidators.isWithinMalaysia(5.4141, 100.3288), isTrue);
      // Kuching, Sarawak
      expect(LqInputValidators.isWithinMalaysia(1.5533, 110.3592), isTrue);

      // London, UK (outside)
      expect(LqInputValidators.isWithinMalaysia(51.5074, -0.1278), isFalse);
      // Tokyo, Japan (outside)
      expect(LqInputValidators.isWithinMalaysia(35.6762, 139.6503), isFalse);
    });
  });

  group('BiometricAuthService', () {
    test('MockBiometricAuthService stores and clears last user session', () async {
      final mock = MockBiometricAuthService(supported: true, enabled: false);
      BiometricAuthService.instance = mock;

      expect(await mock.isSupported(), isTrue);
      expect(await mock.isEnabled(), isFalse);

      await mock.setEnabled(true);
      expect(await mock.isEnabled(), isTrue);

      await mock.saveLastUser(email: 'merchant@test.com', role: 'merchant');
      final user = await mock.getLastUser();
      expect(user?['email'], 'merchant@test.com');
      expect(user?['role'], 'merchant');

      await mock.clearLastUser();
      expect(await mock.getLastUser(), isNull);
    });

    test('BiometricAuthService scopes biometric settings per user account on device', () async {
      final mock = MockBiometricAuthService(supported: true, enabled: false);
      BiometricAuthService.instance = mock;

      // Enable for user A
      await mock.setEnabled(true, 'user-a');
      expect(await mock.isEnabled('user-a'), isTrue);

      // User B on same device is not enabled by default
      expect(await mock.isEnabled('user-b'), isFalse);
    });

    test('AuthService resolveEmailFromIdentifier handles direct email', () async {
      final email = await AuthService.instance.resolveEmailFromIdentifier('Kenny@Example.com');
      expect(email, 'kenny@example.com');
    });

    test('AuthService resolveEmailFromIdentifier returns empty for invalid/unregistered identifiers', () async {
      final email = await AuthService.instance.resolveEmailFromIdentifier('@unknown_user_xyz');
      expect(email, isEmpty);
    });

    test('BiometricAuthService maintains session authentication state per user', () {
      final service = MockBiometricAuthService();
      expect(service.isSessionAuthenticated('user-1'), isFalse);
      service.markSessionAuthenticated('user-1');
      expect(service.isSessionAuthenticated('user-1'), isTrue);
      expect(service.isSessionAuthenticated('user-2'), isFalse);

      service.clearSessionAuthentication('user-1');
      expect(service.isSessionAuthenticated('user-1'), isFalse);
    });

    testWidgets('SettingsScreen toggles biometric sign-in', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: false);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(testApp(const SettingsScreen(user: testTourist)));
      await tester.pumpAndSettle();

      expect(find.text('Biometric sign-in'), findsOneWidget);
      final switchFinder = find.byType(Switch).first;
      expect(switchFinder, findsOneWidget);

      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(await mock.isEnabled(), isTrue);
      expect(find.text('Biometric sign-in enabled.'), findsOneWidget);
    });

    testWidgets('LoginScreen displays clean credentials form matching Figma', (tester) async {
      final mock = MockBiometricAuthService(
        supported: true,
        enabled: true,
        initialUser: {'email': 'saved@localquest.test', 'role': 'tourist'},
      );
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(const LoginScreen(role: AccountRole.tourist)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in with biometrics'), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Email address or username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('BiometricGate unlocks immediately when biometrics is disabled', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: false);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(const BiometricGate(
          user: testTourist,
          child: Text('Home Content Unlocked'),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Content Unlocked'), findsOneWidget);
      expect(find.text('Unlock with biometrics'), findsNothing);
    });

    testWidgets('BiometricGate prompts and unlocks when biometrics is enabled', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(const BiometricGate(
          user: testTourist,
          child: Text('Home Content Unlocked'),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Content Unlocked'), findsOneWidget);
    });

    testWidgets('BiometricGate displays password login option when biometric is locked', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true, authSucceeds: false);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(const BiometricGate(
          user: testTourist,
          child: Text('Home Content Unlocked'),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock with biometrics'), findsOneWidget);
      expect(find.text('Proceed to log in with password'), findsOneWidget);
      expect(find.text('Sign out / Switch account'), findsOneWidget);

      // Tap Proceed to log in with password
      await tester.tap(find.byKey(const Key('biometric_gate_proceed_login_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Log in with password'), findsOneWidget);
      expect(find.byKey(const Key('biometric_gate_password_field')), findsOneWidget);
      expect(find.byKey(const Key('biometric_gate_password_submit_btn')), findsOneWidget);
    });

    testWidgets('BiometricGate bypasses prompt if user just authenticated with password', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true);
      mock.markJustAuthenticated();
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(const BiometricGate(
          user: testTourist,
          child: Text('Home Content Unlocked'),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Content Unlocked'), findsOneWidget);
      expect(find.text('Unlock with biometrics'), findsNothing);
    });

    testWidgets('BiometricGate bypasses prompt if user is session authenticated', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true, authSucceeds: false);
      mock.markSessionAuthenticated(testTourist.id);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(const BiometricGate(
          user: testTourist,
          child: Text('Session Authenticated Child'),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Session Authenticated Child'), findsOneWidget);
    });

    testWidgets('BiometricGate sign out caches username and email', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mock = MockBiometricAuthService(supported: true, enabled: true, authSucceeds: false);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(BiometricGate(
          user: testTourist,
          onSignOut: () async {},
          child: const Text('Home Content'),
        )),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('biometric_gate_signout_btn')));
      await tester.pumpAndSettle();

      final cached = await AccountIdentifierCache.lookup('testtourist');
      expect(cached, testTourist.email);
    });
  });

  group('SignupScreen Real-time Validation', () {
    testWidgets('performs real-time debounced checks on username', (tester) async {
      LqInputValidators.checkUsernameAvailability = (username) async {
        return username != 'taken_user';
      };

      await tester.pumpWidget(
        testApp(const SignupScreen(role: AccountRole.tourist)),
      );
      await tester.pumpAndSettle();

      final usernameField = find.widgetWithText(LqField, 'Username');
      expect(usernameField, findsOneWidget);

      // Type an already taken username
      await tester.enterText(usernameField, 'taken_user');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Username is already taken.'), findsOneWidget);

      // Type an available username
      await tester.enterText(usernameField, 'fresh_user');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Username is already taken.'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('VisitedPlacesScreen & Location History', () {
    testWidgets('renders clean empty state without demo simulate buttons', (tester) async {
      UserRepository.instance.mockVisitedPlacesStream = (uid) => const Stream.empty();

      await tester.pumpWidget(testApp(const VisitedPlacesScreen(userId: 'test-tourist')));
      await tester.pumpAndSettle();

      expect(find.text('Visited places'), findsOneWidget);
      expect(find.text('No visited locations found.'), findsOneWidget);
      expect(find.byKey(const Key('visited_places_empty_simulate_btn')), findsNothing);
      expect(find.byKey(const Key('visited_places_demo_checkin_btn')), findsNothing);
    });

    test('UserRepository recordVisit respects privacy settings', () async {
      UserRepository.instance.mockRecordVisit = ({
        required userId,
        required name,
        required area,
        businessId,
        visitedAt,
      }) async {
        return false; // Disabled by privacy toggle
      };

      final recorded = await UserRepository.instance.recordVisit(
        userId: 'test-tourist',
        name: 'Heritage Spot',
        area: 'George Town',
      );

      expect(recorded, isFalse);
    });
  });

  group('MalaysianAddressComponents', () {
    test('parses full Malaysian address string into decomposed components', () {
      const raw = '12, Lengkok Tenggiri, 13500 Permatang Pauh, Pulau Pinang, Malaysia';
      final components = MalaysianAddressComponents.parse(raw);

      expect(components.postcode, '13500');
      expect(components.city, 'Permatang Pauh');
      expect(components.state, 'Pulau Pinang');
      expect(components.street, contains('Lengkok Tenggiri'));
      expect(components.street, isNot(contains('13500')));
      expect(components.street, isNot(contains('Malaysia')));
    });

    test('normalizes state names and aliases', () {
      expect(MalaysianAddressComponents.normalizeState('penang'), 'Pulau Pinang');
      expect(MalaysianAddressComponents.normalizeState('KL'), 'Wilayah Persekutuan Kuala Lumpur');
      expect(MalaysianAddressComponents.normalizeState('Kuala Lumpur'), 'Wilayah Persekutuan Kuala Lumpur');
      expect(MalaysianAddressComponents.normalizeState('Melaka'), 'Melaka');
      expect(MalaysianAddressComponents.normalizeState('Selangor'), 'Selangor');
    });

    test('retains explicit components when provided', () {
      final components = MalaysianAddressComponents.parse(
        'Some Raw Address',
        explicitStreet: 'Jalan Tun Razak',
        explicitPostcode: '50400',
        explicitCity: 'Kuala Lumpur',
        explicitState: 'Wilayah Persekutuan Kuala Lumpur',
      );

      expect(components.street, 'Jalan Tun Razak');
      expect(components.postcode, '50400');
      expect(components.city, 'Kuala Lumpur');
      expect(components.state, 'Wilayah Persekutuan Kuala Lumpur');
    });
  });

  group('HelpCentreScreen and PrivacyScreen role awareness', () {
    testWidgets('HelpCentreScreen shows merchant FAQs for merchant role', (tester) async {
      await tester.pumpWidget(testApp(const HelpCentreScreen(role: AccountRole.merchant)));
      await tester.pumpAndSettle();

      expect(find.text('MERCHANT SUPPORT'), findsOneWidget);
      expect(find.text('How do I verify my SSM registration?'), findsOneWidget);
      expect(find.text('How do campaigns and advertisements work?'), findsOneWidget);
    });

    testWidgets('HelpCentreScreen shows tourist FAQs for tourist role', (tester) async {
      await tester.pumpWidget(testApp(const HelpCentreScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      expect(find.text('SUPPORT'), findsOneWidget);
      expect(find.text('How does automatic place logging work?'), findsOneWidget);
    });

    testWidgets('PrivacyScreen displays merchant specifics for merchant role', (tester) async {
      await tester.pumpWidget(testApp(const PrivacyScreen(role: AccountRole.merchant)));
      await tester.pumpAndSettle();

      expect(find.text('MERCHANT PRIVACY'), findsOneWidget);
      expect(find.textContaining('SSM certificates'), findsOneWidget);
    });
  });

  group('Password Visibility Toggling Across All Screens', () {
    testWidgets('LqField toggles obscureText and switches tooltip between Show and Hide password', (tester) async {
      final controller = TextEditingController(text: 'MySecretPassword123');
      await tester.pumpWidget(
        testApp(LqField(
          key: const Key('test_pwd_field'),
          controller: controller,
          label: 'Password',
          obscureText: true,
        )),
      );
      await tester.pumpAndSettle();

      // Initially obscured
      final textFieldFinder = find.descendant(
        of: find.byKey(const Key('test_pwd_field')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);
      expect(find.byTooltip('Show password'), findsOneWidget);

      // Tap Show password
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();

      // Now revealed
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);

      // Tap Hide password
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();

      // Obscured again
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);
      expect(find.byTooltip('Show password'), findsOneWidget);
    });

    testWidgets('LoginScreen password field toggles visibility', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final pwdField = find.byKey(const Key('login_password_field'));
      expect(pwdField, findsOneWidget);

      final textFieldFinder = find.descendant(
        of: pwdField,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);

      final showBtn = find.descendant(
        of: pwdField,
        matching: find.byTooltip('Show password'),
      );
      expect(showBtn, findsOneWidget);

      await tester.tap(showBtn);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(textFieldFinder).obscureText, isFalse);
      expect(find.descendant(of: pwdField, matching: find.byTooltip('Hide password')), findsOneWidget);
    });

    testWidgets('EmailAddressScreen current password field toggles visibility', (tester) async {
      await tester.pumpWidget(testApp(const EmailAddressScreen(currentEmail: 'tourist@localquest.test')));
      await tester.pumpAndSettle();

      final pwdField = find.byKey(const Key('change_email_password_field'));
      expect(pwdField, findsOneWidget);

      final textFieldFinder = find.descendant(
        of: pwdField,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);

      await tester.tap(find.descendant(of: pwdField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(textFieldFinder).obscureText, isFalse);
    });

    testWidgets('SignupScreen confirm password field toggles visibility', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      // Step 1: name, username, phone, birthday -> Continue
      await tester.enterText(find.widgetWithText(LqField, 'Full name'), 'Test User');
      await tester.enterText(find.widgetWithText(LqField, 'Username'), 'newuser99');
      await tester.enterText(find.widgetWithText(LqField, 'Phone number'), '0123456789');
      await tester.enterText(find.widgetWithText(LqField, 'Birthday'), '1995-05-15');
      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      final confirmField = find.byKey(const Key('signup_confirm_password_field'));
      expect(confirmField, findsOneWidget);

      final textFieldFinder = find.descendant(
        of: confirmField,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);

      await tester.tap(find.descendant(of: confirmField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(textFieldFinder).obscureText, isFalse);
    });

    testWidgets('PasswordSecurityScreen current, new, and confirm fields toggle visibility', (tester) async {
      await tester.pumpWidget(testApp(const PasswordSecurityScreen()));
      await tester.pumpAndSettle();

      // 1. Current password field
      final currentField = find.byKey(const Key('change_password_current_field'));
      expect(currentField, findsOneWidget);
      final currentText = find.descendant(of: currentField, matching: find.byType(TextField));
      expect(tester.widget<TextField>(currentText).obscureText, isTrue);
      await tester.tap(find.descendant(of: currentField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(currentText).obscureText, isFalse);

      // 2. New password field
      final newField = find.byKey(const Key('change_password_new_field'));
      expect(newField, findsOneWidget);
      final newText = find.descendant(of: newField, matching: find.byType(TextField));
      expect(tester.widget<TextField>(newText).obscureText, isTrue);
      await tester.tap(find.descendant(of: newField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(newText).obscureText, isFalse);

      // 3. Confirm password field
      final confirmField = find.byKey(const Key('change_password_confirm_field'));
      expect(confirmField, findsOneWidget);
      final confirmText = find.descendant(of: confirmField, matching: find.byType(TextField));
      expect(tester.widget<TextField>(confirmText).obscureText, isTrue);
      await tester.tap(find.descendant(of: confirmField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(confirmText).obscureText, isFalse);
    });

    testWidgets('PrivacyScreen delete account modal toggles current password visibility', (tester) async {
      await tester.pumpWidget(testApp(const PrivacyScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      // Scroll to delete account button and tap it
      final deleteBtn = find.text('Delete account');
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      final modalPwdField = find.byKey(const Key('delete_account_password_field'));
      expect(modalPwdField, findsOneWidget);

      final textFieldFinder = find.descendant(
        of: modalPwdField,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);

      await tester.tap(find.descendant(of: modalPwdField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(textFieldFinder).obscureText, isFalse);
    });

    testWidgets('BiometricGate password modal toggles password visibility', (tester) async {
      final mock = MockBiometricAuthService(supported: true, enabled: true, authSucceeds: false);
      BiometricAuthService.instance = mock;

      await tester.pumpWidget(
        testApp(BiometricGate(
          user: testTourist,
          onSignOut: () async {},
          child: const Text('Home Content'),
        )),
      );
      await tester.pumpAndSettle();

      // Open password unlock modal
      final pwdOption = find.text('Proceed to log in with password');
      expect(pwdOption, findsOneWidget);
      await tester.tap(pwdOption);
      await tester.pumpAndSettle();

      final pwdField = find.byKey(const Key('biometric_gate_password_field'));
      expect(pwdField, findsOneWidget);
      expect(tester.widget<TextField>(pwdField).obscureText, isTrue);

      await tester.tap(find.descendant(of: pwdField, matching: find.byTooltip('Show password')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(pwdField).obscureText, isFalse);
    });
  });
}
