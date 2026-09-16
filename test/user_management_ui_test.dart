import 'package:collab/core/localquest_theme.dart';
import 'package:collab/core/localquest_location.dart';
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

class _AddressLookupForTest extends PhotonAddressService {
  const _AddressLookupForTest();

  @override
  Future<AddressSuggestion?> reverse(LqLocation location) async =>
      const AddressSuggestion(
        label: '18 Jalan Example, Kuala Lumpur, Malaysia',
        latitude: 3.139,
        longitude: 101.6869,
      );
}

void main() {
  testWidgets(
    'campaign create action stays fixed above nav while list scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const business = Business(
        id: 'b1',
        ownerId: 'merchant-1',
        name: 'Test Cafe',
        category: 'Cafe',
        address: 'Kuala Lumpur',
        phone: '0312345678',
      );
      await tester.pumpWidget(
        app(
          CampaignsScreen(
            user: merchant,
            business: business,
            campaignStream: Stream.value(
              List.generate(
                5,
                (i) => Campaign(
                  id: '$i',
                  ownerId: merchant.id,
                  businessId: business.id,
                  name: 'Offer $i',
                  description: 'Coffee special at this business',
                  type: 'ad',
                  startDate: DateTime(2026),
                  endDate: DateTime(2027),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final create = find.text('Create campaign');
      expect(create, findsOneWidget);
      final before = tester.getRect(create);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(create), before);
      expect(before.bottom, lessThanOrEqualTo(780 - 96));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('campaign poster fills the creative section edge to edge', (
    tester,
  ) async {
    const business = Business(
      id: 'b1',
      ownerId: 'merchant-1',
      name: 'Test Cafe',
      category: 'Cafe',
      address: 'Kuala Lumpur',
      phone: '0312345678',
    );
    await tester.pumpWidget(
      app(
        CampaignsScreen(
          user: merchant,
          business: business,
          campaignStream: Stream.value([
            Campaign(
              id: 'poster-campaign',
              ownerId: merchant.id,
              businessId: business.id,
              name: 'Full-bleed poster',
              description: 'This poster should be the creative background.',
              type: 'ad',
              imageUrl: 'https://res.cloudinary.com/example/image.jpg',
              startDate: DateTime(2026),
              endDate: DateTime(2027),
            ),
          ]),
        ),
      ),
    );
    await tester.pump();

    final image = find.byType(Image);
    final card = find.byType(LqCard);
    expect(image, findsOneWidget);
    expect(card, findsOneWidget);
    expect(tester.getRect(image).left, tester.getRect(card).left);
    expect(tester.getRect(image).right, tester.getRect(card).right);
    expect(tester.getRect(image).height, 178);
  });

  testWidgets('voucher form rejects blank offer before reaching review', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const CampaignEditor(
          user: merchant,
          businessId: 'b1',
          initialType: 'voucher',
        ),
      ),
    );
    await tester.ensureVisible(find.text('Next: Value & limits'));
    await tester.tap(find.text('Next: Value & limits'));
    await tester.pumpAndSettle();
    expect(find.text('Name must contain 3–80 characters.'), findsOneWidget);
    expect(
      find.text('Description must contain 20–1500 characters.'),
      findsOneWidget,
    );
    expect(find.text('Review your offer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Photon address result preserves label and coordinates', () {
    final suggestion = AddressSuggestion.fromPhotonFeature({
      'properties': {
        'name': 'Noka Coffee',
        'street': 'Jalan Sultan Ismail',
        'postcode': '50250',
        'city': 'Kuala Lumpur',
        'country': 'Malaysia',
      },
      'geometry': {
        'coordinates': [101.7080, 3.1478],
      },
    });

    expect(suggestion.label, contains('Noka Coffee'));
    expect(suggestion.label, contains('Kuala Lumpur'));
    expect(suggestion.latitude, 3.1478);
    expect(suggestion.longitude, 101.7080);
  });

  testWidgets('map picker offers current location and hides coordinates', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        LqAddressField(
          controller: controller,
          label: 'Business address',
          initialLocation: const LqLocation(
            latitude: 3.139,
            longitude: 101.6869,
            address: '18 Jalan Example, Kuala Lumpur, Malaysia',
          ),
          service: const _AddressLookupForTest(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Pin location on map'));
    await tester.pump();

    expect(find.byTooltip('Use my current location'), findsOneWidget);
    expect(
      find.text('18 Jalan Example, Kuala Lumpur, Malaysia'),
      findsOneWidget,
    );
    expect(find.textContaining('3.139000'), findsNothing);
  });

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
    expect(find.text('Email address or username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('tourist profile exposes required account features', (
    tester,
  ) async {
    await tester.pumpWidget(app(const TouristProfileScreen(user: tourist)));

    expect(find.text('Test Tourist'), findsOneWidget);
    expect(find.text('1,250/600XP'), findsOneWidget);
    expect(find.text('My vouchers'), findsOneWidget);
    expect(find.text('Reviews & ratings'), findsOneWidget);
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('Daily check-in'), findsOneWidget);
    expect(find.text('Visited places'), findsOneWidget);
    expect(find.text('My Friends'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.byType(LqTierBadge), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.chevron_right &&
            widget.color == LqColors.primary,
      ),
      findsOneWidget,
    );
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
    expect(find.text('Notifications'), findsOneWidget);
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
        home: const TouristHome(user: tourist, initialIndex: 2),
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

  testWidgets('floating navigation overlays content without a reserved bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: localQuestTheme(),
        home: LqPage(
          bottomNavigationBar: LqFloatingNavBar(
            selectedIndex: 2,
            onSelected: (_) {},
            items: const [
              (Icons.explore_outlined, 'Discover'),
              (Icons.confirmation_num_outlined, 'Rewards'),
              (Icons.person_outline, 'Profile'),
            ],
            profileInitials: 'TT',
          ),
          child: const ColoredBox(color: Colors.orange),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNull);
    expect(
      find.ancestor(
        of: find.byType(LqFloatingNavBar),
        matching: find.byType(Stack),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('merchant profile links to settings and business management', (
    tester,
  ) async {
    await tester.pumpWidget(app(const MerchantProfile(user: merchant)));

    expect(find.text('@testmerchant'), findsOneWidget);
    expect(find.text('merchant@localquest.test'), findsOneWidget);
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
    expect(find.text('Next: Schedule & vouchers'), findsOneWidget);

    await tester.pumpWidget(app(const BusinessEditor(user: merchant)));
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Business category'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.byType(LqAddressField), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
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
    await tester.ensureVisible(find.byIcon(Icons.calendar_month_outlined));
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

  testWidgets(
    'merchant overview splits campaigns into recent ads and latest vouchers',
    (tester) async {
      const business = Business(
        id: 'b1',
        ownerId: 'merchant-1',
        name: 'Bukit Bintang Cafe',
        category: 'Cafe',
        address: '10 Jalan Bukit Bintang',
        area: 'Bukit Bintang',
        phone: '0312345678',
      );
      final campaigns = [
        Campaign(
          id: 'ad-1',
          ownerId: merchant.id,
          businessId: business.id,
          name: 'Summer Drink Special',
          description: '50% off seasonal mango cooler',
          type: 'ad',
          status: 'active',
          views: 120,
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 8, 31),
        ),
        Campaign(
          id: 'v-1',
          ownerId: merchant.id,
          businessId: business.id,
          name: 'RM10 Welcome Voucher',
          description: 'Save RM10 on any pastry combo',
          type: 'voucher',
          status: 'active',
          claims: 42,
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 12, 31),
        ),
      ];

      await tester.pumpWidget(
        app(
          MerchantOverview(
            user: merchant,
            business: business,
            openCampaigns: () {},
            campaignStream: Stream.value(campaigns),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT ADS'), findsOneWidget);
      expect(find.text('Summer Drink Special'), findsWidgets);
      expect(find.text('LATEST VOUCHERS'), findsOneWidget);
      // The expired ad means the voucher becomes the active campaign, so it
      // appears in both the LIVE CAMPAIGN spotlight and the LATEST VOUCHERS list.
      expect(find.text('RM10 Welcome Voucher'), findsWidgets);
      expect(find.text('42 claimed · ACTIVE'), findsOneWidget);
    },
  );

  testWidgets('business editor exposes area / city, postcode, and state fields', (tester) async {
    await tester.pumpWidget(app(const BusinessEditor(user: merchant)));
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('Postcode'), findsOneWidget);
    expect(find.text('Area / city'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(
      find.widgetWithText(LqField, 'Area / city'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tourist profile displays stat subtitle badges and journey items',
    (tester) async {
      await tester.pumpWidget(app(const TouristProfileScreen(user: tourist)));

      expect(find.text('3 expiring soon'), findsOneWidget);
      expect(find.text('Top 8% storyteller'), findsOneWidget);

      // My vouchers and Reviews & ratings items are present but no longer open sheets
      expect(find.text('My vouchers'), findsOneWidget);
      expect(find.text('Reviews & ratings'), findsOneWidget);

      await tester.ensureVisible(find.text('Missions'));
      await tester.tap(find.text('Missions'));
      await tester.pumpAndSettle();
      expect(find.text('SIDE QUESTS'), findsOneWidget);
      expect(find.text('Dynamic Missions'), findsOneWidget);
    },
  );
}
