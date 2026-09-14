import 'package:collab/core/localquest_theme.dart';
import 'package:collab/core/localquest_widgets.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/models/map_location.dart';
import 'package:collab/screens/interactive_map/map_location_details.dart';
import 'package:collab/screens/merchant_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget testApp(Widget home) => MaterialApp(
      theme: localQuestTheme(),
      home: Scaffold(body: home),
    );

const testMerchant = AppUser(
  id: 'merchant-test-1',
  email: 'merchant@test.com',
  displayName: 'Merchant Owner',
  username: '@merchant_owner',
  role: AccountRole.merchant,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lqIsDietaryCategory Logic Tests', () {
    test('returns true for food and beverage categories', () {
      expect(lqIsDietaryCategory('Cafe'), isTrue);
      expect(lqIsDietaryCategory('Restaurant'), isTrue);
      expect(lqIsDietaryCategory('Food & Beverage'), isTrue);
      expect(lqIsDietaryCategory('cafe'), isTrue);
      expect(lqIsDietaryCategory('RESTAURANT'), isTrue);
      expect(lqIsDietaryCategory('Bakery & Pastry'), isTrue);
      expect(lqIsDietaryCategory('Coffee Roastery'), isTrue);
      expect(lqIsDietaryCategory('Dessert House'), isTrue);
      expect(lqIsDietaryCategory('Local Eatery'), isTrue);
      expect(lqIsDietaryCategory('Heritage Bistro'), isTrue);
    });

    test('returns false for non-food categories', () {
      expect(lqIsDietaryCategory('Artisan'), isFalse);
      expect(lqIsDietaryCategory('Retail'), isFalse);
      expect(lqIsDietaryCategory('Accommodation'), isFalse);
      expect(lqIsDietaryCategory('Attraction'), isFalse);
      expect(lqIsDietaryCategory('Tour & activity'), isFalse);
      expect(lqIsDietaryCategory('Other'), isFalse);
      expect(lqIsDietaryCategory(''), isFalse);
      expect(lqIsDietaryCategory('   '), isFalse);
      expect(lqIsDietaryCategory(null), isFalse);
    });
  });

  group('BusinessEditor Category-Specific Halal & Dietary Field Tests', () {
    testWidgets(
      'Halal & dietary certification does not appear for empty or non-food categories (Artisan)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          testApp(const BusinessEditor(user: testMerchant)),
        );
        await tester.pumpAndSettle();

        // Initially no category is selected -> Halal & dietary certification must NOT appear
        expect(find.text('Halal & dietary certification'), findsNothing);

        // Tap Business category selector and pick Artisan
        await tester.tap(find.text('Choose business category'));
        await tester.pumpAndSettle();

        expect(find.text('LOCALQUEST SELECTOR'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Artisan'),
          50,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Artisan'));
        await tester.pumpAndSettle();

        expect(find.text('Artisan'), findsOneWidget);
        // Halal & dietary certification must STILL NOT appear
        expect(find.text('Halal & dietary certification'), findsNothing);
      },
    );

    testWidgets(
      'Halal & dietary certification appears and is required when Cafe is chosen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          testApp(const BusinessEditor(user: testMerchant)),
        );
        await tester.pumpAndSettle();

        // Select Cafe
        await tester.tap(find.text('Choose business category'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cafe'));
        await tester.pumpAndSettle();

        expect(find.text('Cafe'), findsOneWidget);
        // Halal & dietary certification field must now appear
        expect(find.text('Halal & dietary certification'), findsOneWidget);

        // Attempting to save without selecting dietary certification triggers validation
        await tester.ensureVisible(find.text('Save business'));
        await tester.tap(find.text('Save business'));
        await tester.pumpAndSettle();

        // Validation error appears for dietary certification
        expect(
          find.text('Please choose a Halal & dietary certification.'),
          findsOneWidget,
        );

        // Tap Halal & dietary certification dropdown and select Halal Certified
        await tester.ensureVisible(find.text('Halal & dietary certification'));
        await tester.tap(
          find.text('Choose halal & dietary certification'),
        );
        await tester.pumpAndSettle();

        expect(find.text('LOCALQUEST SELECTOR'), findsOneWidget);
        await tester.tap(find.text('Halal Certified'));
        await tester.pumpAndSettle();

        expect(find.text('Halal Certified'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching from Cafe to Artisan hides field and resets dietary status',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          testApp(const BusinessEditor(user: testMerchant)),
        );
        await tester.pumpAndSettle();

        // Select Cafe
        await tester.tap(find.text('Choose business category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cafe'));
        await tester.pumpAndSettle();

        expect(find.text('Halal & dietary certification'), findsOneWidget);

        // Pick Halal Certified
        await tester.ensureVisible(find.text('Choose halal & dietary certification'));
        await tester.tap(
          find.text('Choose halal & dietary certification'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Halal Certified'));
        await tester.pumpAndSettle();
        expect(find.text('Halal Certified'), findsOneWidget);

        // Now switch category to Artisan
        await tester.ensureVisible(find.text('Cafe'));
        await tester.tap(find.text('Cafe'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Artisan'),
          50,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Artisan'));
        await tester.pumpAndSettle();

        // Halal & dietary certification field is gone
        expect(find.text('Halal & dietary certification'), findsNothing);
        expect(find.text('Halal Certified'), findsNothing);
      },
    );

    testWidgets(
      'Existing business with Cafe displays dietary status; Artisan business omits it',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cafeBusiness = Business(
          id: 'biz-cafe',
          ownerId: testMerchant.id,
          name: 'Penang Roast Cafe',
          category: 'Cafe',
          dietaryStatus: 'Muslim-Friendly / Pork-Free',
          address: '45 Beach Street',
          phone: '0123456789',
        );

        await tester.pumpWidget(
          testApp(BusinessEditor(
            key: const ValueKey('cafe_biz_editor'),
            user: testMerchant,
            business: cafeBusiness,
          )),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cafe'), findsOneWidget);
        expect(find.text('Halal & dietary certification'), findsOneWidget);
        expect(find.text('Muslim-Friendly / Pork-Free'), findsOneWidget);

        // Artisan business
        final artisanBusiness = Business(
          id: 'biz-artisan',
          ownerId: testMerchant.id,
          name: 'Georgetown Batik Art',
          category: 'Artisan',
          dietaryStatus: null,
          address: '12 Armenian Street',
          phone: '0123456789',
        );

        await tester.pumpWidget(
          testApp(BusinessEditor(
            key: const ValueKey('artisan_biz_editor'),
            user: testMerchant,
            business: artisanBusiness,
          )),
        );
        await tester.pumpAndSettle();

        expect(find.text('Artisan'), findsOneWidget);
        expect(find.text('Halal & dietary certification'), findsNothing);
      },
    );
  });

  group('MapLocation & MapLocationDetails Dietary Tests', () {
    testWidgets(
      'Displays Halal & dietary certification section in MapLocationDetails when present',
      (tester) async {
        const locationWithDietary = MapLocation(
          id: 'business:biz-1',
          type: MapLocationType.business,
          title: 'Aroma Nasi Kandar',
          latitude: 5.4141,
          longitude: 100.3288,
          category: 'Restaurant',
          dietaryStatus: 'Halal Certified',
          address: 'Chulia Street, George Town',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MapLocationDetails(
                location: locationWithDietary,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Halal & dietary certification'), findsOneWidget);
        expect(find.text('Halal Certified'), findsOneWidget);
      },
    );

    testWidgets(
      'Omits Halal & dietary certification section in MapLocationDetails when absent',
      (tester) async {
        const locationWithoutDietary = MapLocation(
          id: 'business:biz-2',
          type: MapLocationType.business,
          title: 'Penang Woodcraft Studio',
          latitude: 5.4141,
          longitude: 100.3288,
          category: 'Artisan',
          address: 'Armenian Street, George Town',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MapLocationDetails(
                location: locationWithoutDietary,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Halal & dietary certification'), findsNothing);
      },
    );
  });
}
