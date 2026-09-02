import 'package:collab/models/localquest_models.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/screens/auth_screens.dart';
import 'package:collab/screens/merchant_screens.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tourist = AppUser(
    id: 'tourist-test',
    email: 'tourist@example.com',
    displayName: 'Test Tourist',
    username: '@testtourist',
    role: AccountRole.tourist,
  );
  const merchant = AppUser(
    id: 'merchant-test',
    email: 'merchant@example.com',
    displayName: 'Test Merchant',
    username: '@testmerchant',
    role: AccountRole.merchant,
  );

  Widget app(Widget home) => MaterialApp(home: home);

  testWidgets(
    'role selection opens tourist and merchant authentication pages',
    (tester) async {
      await tester.pumpWidget(app(const AccountTypeScreen()));
      expect(find.text('How will you use\nLocalQuest?'), findsOneWidget);
      expect(find.text('Tourist'), findsOneWidget);
      expect(find.text('Merchant'), findsOneWidget);

      await tester.tap(find.text('Tourist'));
      await tester.pumpAndSettle();
      expect(find.text('TOURIST ACCOUNT'), findsOneWidget);
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.tap(find.text('CHANGE ACCOUNT TYPE'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merchant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('MERCHANT ACCOUNT'), findsOneWidget);
      expect(find.text('Business name'), findsOneWidget);
      expect(find.text('Business category'), findsOneWidget);
      expect(find.text('Primary business address'), findsOneWidget);
    },
  );

  testWidgets('account-management forms expose all required security actions', (
    tester,
  ) async {
    await tester.pumpWidget(app(const AccountDetailsScreen(user: tourist)));
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    await tester.pumpWidget(
      app(const EmailAddressScreen(currentEmail: 'tourist@example.com')),
    );
    expect(find.text('New email address'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('Send verification'), findsOneWidget);

    await tester.pumpWidget(app(const PasswordSecurityScreen()));
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);

    await tester.pumpWidget(app(const ForgotPasswordScreen()));
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tester.pumpWidget(app(const HelpCentreScreen()));
    expect(find.text('Help centre'), findsOneWidget);

    await tester.pumpWidget(app(const PrivacyScreen()));
    expect(find.text('Privacy & data'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('merchant editors expose business campaign and voucher CRUD', (
    tester,
  ) async {
    await tester.pumpWidget(app(const BusinessEditor(user: merchant)));
    expect(find.text('Add business'), findsOneWidget);
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Business category'), findsOneWidget);
    expect(find.byType(LqDropdownField), findsOneWidget);
    expect(find.text('Registration number'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('Save business'), findsOneWidget);

    await tester.pumpWidget(app(const CampaignEditor(user: merchant)));
    expect(find.text('Create campaign'), findsOneWidget);
    expect(find.text('Promotional ad'), findsOneWidget);
    expect(find.text('Voucher'), findsOneWidget);
    expect(find.text('Campaign name'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    await tester.pumpWidget(
      app(
        const CampaignEditor(
          key: ValueKey('voucher-editor'),
          user: merchant,
          initialType: 'voucher',
        ),
      ),
    );
    expect(find.text('Create voucher'), findsOneWidget);
    expect(find.text('Voucher name'), findsOneWidget);
  });
}
