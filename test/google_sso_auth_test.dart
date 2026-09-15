import 'package:collab/core/input_validators.dart';
import 'package:collab/core/localquest_location.dart';
import 'package:collab/core/localquest_theme.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/auth_screens.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:collab/services/localquest_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget testApp(Widget home) => MaterialApp(
  theme: localQuestTheme(),
  home: Scaffold(body: home),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LqInputValidators.checkUsernameAvailability = (u) async => true;
    LqInputValidators.checkEmailAvailability = (e) async => true;
  });

  group('Google SSO UI Tests', () {
    testWidgets('LoginScreen displays decorative dashed divider and Google button for Tourist', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      // Verify Sign in button exists
      final signInBtn = find.widgetWithText(LqButton, 'Sign in');
      expect(signInBtn, findsOneWidget);

      // Verify decorative dashed divider exists
      final dashedDividers = find.byType(LqDashedDivider);
      expect(dashedDividers, findsWidgets);

      // Verify Sign in with Google button exists
      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign in with Google');
      expect(googleBtn, findsOneWidget);
    });

    testWidgets('LoginScreen displays decorative dashed divider and Google button for Merchant', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.merchant)));
      await tester.pumpAndSettle();

      final signInBtn = find.widgetWithText(LqButton, 'Sign in');
      expect(signInBtn, findsOneWidget);

      final dashedDividers = find.byType(LqDashedDivider);
      expect(dashedDividers, findsWidgets);

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign in with Google');
      expect(googleBtn, findsOneWidget);
    });

    testWidgets('SignupScreen step 2 displays dashed divider and Google button for Tourist', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      // Step 2 Continue button
      final continueBtn = find.widgetWithText(LqButton, 'Continue');
      expect(continueBtn, findsOneWidget);

      // Dashed divider below continue
      final dashedDividers = find.byType(LqDashedDivider);
      expect(dashedDividers, findsWidgets);

      // Google signup button
      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign up with Google');
      expect(googleBtn, findsOneWidget);
    });

    testWidgets('SignupScreen step 2 displays dashed divider and Google button for Merchant', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen(role: AccountRole.merchant)));
      await tester.pumpAndSettle();

      final continueBtn = find.widgetWithText(LqButton, 'Continue');
      expect(continueBtn, findsOneWidget);

      final dashedDividers = find.byType(LqDashedDivider);
      expect(dashedDividers, findsWidgets);

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign up with Google');
      expect(googleBtn, findsOneWidget);
    });

    testWidgets('SignupScreen step 3 displays dashed divider and Google button for Tourist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(testApp(const SignupScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      // Fill step 2 fields
      final nameField = find.widgetWithText(LqField, 'Full name');
      final usernameField = find.widgetWithText(LqField, 'Username');
      final phoneField = find.widgetWithText(LqField, 'Phone number');

      await tester.enterText(nameField, 'Jane Doe');
      await tester.enterText(usernameField, 'janedoe');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(phoneField, '0123456789');
      await tester.pumpAndSettle();

      // Tap Continue
      final continueBtn = find.widgetWithText(LqButton, 'Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Now on Step 3
      final createAccountBtn = find.widgetWithText(LqButton, 'Create account');
      expect(createAccountBtn, findsOneWidget);

      final dashedDividers = find.byType(LqDashedDivider);
      expect(dashedDividers, findsWidgets);

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign up with Google');
      expect(googleBtn, findsOneWidget);
    });

    testWidgets('SignupScreen step 3 displays dashed divider and Google button for Merchant', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(testApp(const SignupScreen(role: AccountRole.merchant)));
      await tester.pumpAndSettle();

      // Fill step 2 fields
      await tester.enterText(find.widgetWithText(LqField, 'Business name'), 'Local Cafe');
      await tester.enterText(find.widgetWithText(LqField, 'Business phone'), '0123456789');

      // Select category
      final categoryDropdown = find.widgetWithText(LqDropdownField, 'Business category');
      await tester.ensureVisible(categoryDropdown);
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artisan').last);
      await tester.pumpAndSettle();

      // Enter address
      final addressFinder = find.descendant(
        of: find.byType(LqAddressField),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(addressFinder);
      await tester.enterText(addressFinder, '123 Market Street, Georgetown');
      await tester.pumpAndSettle();

      final postcodeFinder = find.widgetWithText(LqField, 'Postcode');
      await tester.ensureVisible(postcodeFinder);
      await tester.enterText(postcodeFinder, '10200');

      final cityFinder = find.widgetWithText(LqField, 'Area / city');
      await tester.ensureVisible(cityFinder);
      await tester.enterText(cityFinder, 'Georgetown');

      final stateDropdown = find.widgetWithText(LqDropdownField, 'State');
      await tester.ensureVisible(stateDropdown);
      await tester.tap(stateDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pulau Pinang').last);
      await tester.pumpAndSettle();

      // Tap Continue
      final continueBtn = find.widgetWithText(LqButton, 'Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Now on Step 3
      final createAccountBtn = find.widgetWithText(LqButton, 'Create account');
      expect(createAccountBtn, findsOneWidget);

      final dashedDividers = find.byType(LqDashedDivider);
      expect(dashedDividers, findsWidgets);

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign up with Google');
      expect(googleBtn, findsOneWidget);
    });
  });

  group('Google SSO Interaction and Auth Flow Tests', () {
    const testUser = AppUser(
      id: 'google-uid-123',
      email: 'alex@localquest.test',
      displayName: 'Alex Smith',
      username: '@alexsmith',
      role: AccountRole.tourist,
    );

    testWidgets('LoginScreen triggers Google Sign-in and navigates on success', (tester) async {
      bool called = false;
      AuthService.instance.mockSignInWithGoogle = ({
        required AccountRole expectedRole,
        Map<String, dynamic>? additionalData,
      }) async {
        called = true;
        expect(expectedRole, AccountRole.tourist);
        return testUser;
      };

      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign in with Google');
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('LoginScreen handles canceled Google Sign-in gracefully', (tester) async {
      AuthService.instance.mockSignInWithGoogle = ({
        required AccountRole expectedRole,
        Map<String, dynamic>? additionalData,
      }) async {
        return null; // Canceled
      };

      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign in with Google');
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      // Still on LoginScreen
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('LoginScreen displays error message when role does not match', (tester) async {
      AuthService.instance.mockSignInWithGoogle = ({
        required AccountRole expectedRole,
        Map<String, dynamic>? additionalData,
      }) async {
        throw const LocalQuestException(
          'This account is registered as a Merchant. Change the selected account type.',
        );
      };

      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      final googleBtn = find.widgetWithText(LqGoogleButton, 'Sign in with Google');
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('This account is registered as a Merchant. Change the selected account type.'),
        findsOneWidget,
      );
    });

    testWidgets('SignupScreen step 2 triggers Google Sign-up with entered profile fields', (tester) async {
      Map<String, dynamic>? capturedData;
      AuthService.instance.mockSignInWithGoogle = ({
        required AccountRole expectedRole,
        Map<String, dynamic>? additionalData,
      }) async {
        capturedData = additionalData;
        expect(expectedRole, AccountRole.tourist);
        return testUser;
      };

      await tester.pumpWidget(testApp(const SignupScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(LqField, 'Full name'), 'Alex Smith');
      await tester.enterText(find.widgetWithText(LqField, 'Username'), 'alexsmith');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.widgetWithText(LqField, 'Phone number'), '0198887777');
      await tester.pumpAndSettle();

      final googleBtn = find.byKey(const Key('signup_google_btn_step2'));
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(capturedData, isNotNull);
      expect(capturedData!['displayName'], 'Alex Smith');
      expect(capturedData!['username'], 'alexsmith');
      expect(capturedData!['phone'], '0198887777');
    });

    testWidgets('SignupScreen Google sign-up brings user back to LoginScreen with email prefilled', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AuthService.instance.mockSignInWithGoogle = ({
        required AccountRole expectedRole,
        Map<String, dynamic>? additionalData,
      }) async {
        return testUser;
      };

      await tester.pumpWidget(testApp(const LoginScreen(role: AccountRole.tourist)));
      await tester.pumpAndSettle();

      // Tap Create an account link to navigate to SignupScreen
      final createAccountLink = find.text('Create an account');
      await tester.ensureVisible(createAccountLink);
      await tester.tap(createAccountLink);
      await tester.pumpAndSettle();

      // We are now on SignupScreen
      expect(find.text('Tell us about you.'), findsOneWidget);

      // Tap Sign up with Google on step 2
      final googleBtn = find.byKey(const Key('signup_google_btn_step2'));
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      // User should be brought back to LoginScreen
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text(testUser.email), findsOneWidget);
    });
  });

  group('Settings Google Account Link/Unlink Tests', () {
    const touristUser = AppUser(
      id: 'tourist_123',
      email: 'tourist@localquest.my',
      displayName: 'Tourist Lee',
      username: '@tourist_lee',
      role: AccountRole.tourist,
    );

    const merchantUser = AppUser(
      id: 'merchant_123',
      email: 'merchant@localquest.my',
      displayName: 'Merchant Tan',
      username: '@merchant_tan',
      role: AccountRole.merchant,
    );

    testWidgets('SettingsScreen displays Connected Accounts with Google Account for Merchant', (tester) async {
      AuthService.instance.mockIsGoogleLinked = ([uid]) async => false;
      AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => null;

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const SettingsScreen(user: merchantUser),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CONNECTED ACCOUNTS'), findsOneWidget);
      expect(find.text('Google Account'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      // Merchant should NOT have Spotify
      expect(find.text('Spotify Music'), findsNothing);
    });

    testWidgets('SettingsScreen displays Connected Accounts with Google Account and Spotify for Tourist', (tester) async {
      AuthService.instance.mockIsGoogleLinked = ([uid]) async => false;
      AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => null;

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const SettingsScreen(user: touristUser),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CONNECTED ACCOUNTS'), findsOneWidget);
      expect(find.text('Google Account'), findsOneWidget);
      expect(find.text('Spotify Music'), findsOneWidget);
    });

    testWidgets('SettingsScreen displays Linked Google email and Unlink button when linked', (tester) async {
      AuthService.instance.mockIsGoogleLinked = ([uid]) async => true;
      AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => 'tourist.google@gmail.com';

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const SettingsScreen(user: touristUser),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Google Account'), findsOneWidget);
      expect(find.text('Connected · tourist.google@gmail.com'), findsOneWidget);
      expect(find.text('Unlink'), findsOneWidget);
    });

    testWidgets('Tapping Connect triggers linkGoogleAccount', (tester) async {
      bool linkCalled = false;
      AuthService.instance.mockIsGoogleLinked = ([uid]) async => false;
      AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => null;
      AuthService.instance.mockLinkGoogleAccount = () async {
        linkCalled = true;
        AuthService.instance.mockIsGoogleLinked = ([uid]) async => true;
        AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => 'linked@gmail.com';
        return true;
      };

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const SettingsScreen(user: merchantUser),
      ));
      await tester.pumpAndSettle();

      final connectBtn = find.text('Connect');
      expect(connectBtn, findsOneWidget);
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      expect(linkCalled, isTrue);
      expect(find.text('Connected · linked@gmail.com'), findsOneWidget);
    });

    testWidgets('Tapping Unlink when Google is only provider prompts setting password', (tester) async {
      AuthService.instance.mockIsGoogleLinked = ([uid]) async => true;
      AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => 'googleonly@gmail.com';
      AuthService.instance.mockCanUnlinkGoogle = () async => false;

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const SettingsScreen(user: touristUser),
      ));
      await tester.pumpAndSettle();

      final unlinkBtn = find.text('Unlink');
      await tester.ensureVisible(unlinkBtn);
      await tester.tap(unlinkBtn);
      await tester.pumpAndSettle();

      expect(find.text('Cannot Unlink Google'), findsOneWidget);
      expect(find.text('Set Password'), findsOneWidget);
    });

    testWidgets('Tapping Unlink when user has other provider unlinks upon confirmation', (tester) async {
      bool unlinkCalled = false;
      AuthService.instance.mockIsGoogleLinked = ([uid]) async => true;
      AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => 'tourist@gmail.com';
      AuthService.instance.mockCanUnlinkGoogle = () async => true;
      AuthService.instance.mockUnlinkGoogleAccount = () async {
        unlinkCalled = true;
        AuthService.instance.mockIsGoogleLinked = ([uid]) async => false;
        AuthService.instance.mockGetLinkedGoogleEmail = ([uid]) async => null;
      };

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const SettingsScreen(user: merchantUser),
      ));
      await tester.pumpAndSettle();

      final unlinkBtn = find.text('Unlink');
      await tester.ensureVisible(unlinkBtn);
      await tester.tap(unlinkBtn);
      await tester.pumpAndSettle();

      expect(find.text('Unlink Google Account?'), findsOneWidget);
      // Tap Unlink on the dialog
      final confirmBtn = find.widgetWithText(FilledButton, 'Unlink');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(unlinkCalled, isTrue);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('PasswordSecurityScreen shows Set account password when user has no password', (tester) async {
      AuthService.instance.mockHasPassword = () async => false;

      await tester.pumpWidget(MaterialApp(
        theme: localQuestTheme(),
        home: const PasswordSecurityScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Set account password'), findsOneWidget);
      expect(find.byKey(const Key('change_password_current_field')), findsNothing);
      expect(find.byKey(const Key('change_password_new_field')), findsOneWidget);
      expect(find.byKey(const Key('change_password_confirm_field')), findsOneWidget);
    });
  });
}
