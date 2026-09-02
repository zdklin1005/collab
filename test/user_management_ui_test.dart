import 'package:collab/core/localquest_theme.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/auth_screens.dart';
import 'package:collab/screens/merchant_screens.dart';
import 'package:collab/screens/tourist_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tourist = AppUser(
  id: 'tourist-1',
  email: 'tourist@localquest.test',
  displayName: 'Test Tourist',
  username: '@testtourist',
  role: AccountRole.tourist,
  exp: 1250,
  level: 2,
  voucherCount: 3,
  reviewCount: 4,
);

const merchant = AppUser(
  id: 'merchant-1',
  email: 'merchant@localquest.test',
  displayName: 'Test Merchant',
  username: '@testmerchant',
  role: AccountRole.merchant,
);

Widget app(Widget home) => MaterialApp(
  theme: localQuestTheme(),
  home: Scaffold(body: home),
);

void main() {
  testWidgets('account selection fits a compact phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const AccountTypeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Tourist'), findsOneWidget);
    expect(find.text('Merchant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role selection opens tourist registration', (tester) async {
    await tester.pumpWidget(app(const AccountTypeScreen(registration: true)));

    expect(find.text('How will you use\nLocalQuest?'), findsOneWidget);
    expect(find.text('Tourist'), findsOneWidget);
    expect(find.text('Merchant'), findsOneWidget);

    await tester.tap(find.text('Tourist'));
    await tester.pumpAndSettle();

    expect(find.textContaining('TOURIST ACCOUNT'), findsOneWidget);
    expect(find.text('Tell us about you.'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
  });

  testWidgets('login exposes credentials and password recovery', (
    tester,
  ) async {
    await tester.pumpWidget(app(const LoginScreen(role: AccountRole.tourist)));

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('tourist profile exposes required account features', (
    tester,
  ) async {
    await tester.pumpWidget(app(const TouristProfileScreen(user: tourist)));

    expect(find.text('Test Tourist'), findsOneWidget);
    expect(find.text('1250/3,000XP'), findsOneWidget);
    expect(find.text('My vouchers'), findsOneWidget);
    expect(find.text('Reviews & ratings'), findsOneWidget);
    expect(find.text('Visited places'), findsOneWidget);
    expect(find.byType(LqTierBadge), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LqTierBadge),
        matching: find.byType(Chip),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Test Tourist'));
    await tester.pumpAndSettle();

    expect(find.text('Account details'), findsOneWidget);
    Navigator.of(tester.element(find.text('Account details'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    Navigator.of(tester.element(find.text('Notifications'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password & security'), findsOneWidget);
    expect(find.text('Trip notifications'), findsOneWidget);
    expect(find.text('Location history'), findsOneWidget);
    expect(find.text('Privacy & data'), findsOneWidget);
  });

  testWidgets('profile tier and notification layout fit a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const TouristProfileScreen(user: tourist)));
    expect(find.text('EXPLORER · LEVEL 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const NotificationsScreen(user: tourist)));
    await tester.pumpAndSettle();

    final backPosition = tester.getTopLeft(find.text('PROFILE'));
    final titlePosition = tester.getTopLeft(find.text('Notifications'));
    expect(backPosition.dx, lessThan(80));
    expect(titlePosition.dx, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LocalQuest campaign selector has themed interactive tabs', (
    tester,
  ) async {
    var selected = 'ad';
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: LqSegmentedControl<String>(
              segments: const [
                ('ad', 'Promotional ads'),
                ('voucher', 'Vouchers'),
              ],
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SegmentedButton<String>), findsNothing);
    await tester.tap(find.text('Vouchers'));
    await tester.pumpAndSettle();
    expect(selected, 'voucher');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tourist home keeps the selected page visible above navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: localQuestTheme(),
        home: const TouristHome(user: tourist),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MY PASSPORT'), findsOneWidget);
    expect(find.text('Test Tourist'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LqFloatingNavBar),
        matching: find.text('Profile'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(TouristProfileScreen)).height,
      greaterThan(300),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('merchant profile links to settings and business management', (
    tester,
  ) async {
    await tester.pumpWidget(app(const MerchantProfile(user: merchant)));

    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('Vouchers'), findsOneWidget);
    expect(find.text('Business registrations'), findsOneWidget);
    expect(find.text('Manage workspace for'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password & security'), findsOneWidget);
  });

  testWidgets('merchant editors expose create fields', (tester) async {
    await tester.pumpWidget(app(const CampaignEditor(user: merchant)));
    expect(find.text('Promotional ad'), findsOneWidget);
    expect(find.text('Voucher'), findsOneWidget);
    expect(find.text('Campaign name'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    await tester.pumpWidget(app(const BusinessEditor(user: merchant)));
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Business category'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('Save business'), findsOneWidget);
  });

  testWidgets('custom category and calendar selectors complete a choice', (
    tester,
  ) async {
    await tester.pumpWidget(app(const BusinessEditor(user: merchant)));
    await tester.tap(find.text('Choose business category'));
    await tester.pumpAndSettle();

    expect(find.text('LOCALQUEST SELECTOR'), findsOneWidget);
    await tester.tap(find.text('Cafe'));
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const AccountDetailsScreen(user: tourist)));
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.text('LOCALQUEST CALENDAR'), findsOneWidget);
    expect(find.text('Select birthday'), findsOneWidget);
    await tester.tap(find.text('Choose date').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed logout immediately removes nested settings route', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: localQuestTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      user: merchant,
                      onSignOut: () async {
                        signedOut = true;
                      },
                    ),
                  ),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(signedOut, isTrue);
  });

  testWidgets('logout requires confirmation', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmLqSignOut(context, () async {
              signedOut = true;
            }),
            child: const Text('Log out'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of LocalQuest?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(signedOut, isFalse);
  });
}
