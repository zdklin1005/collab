import 'package:collab/core/demo_database_seeder.dart';
import 'package:collab/core/localquest_theme.dart';
import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/merchant_screens.dart';
import 'package:collab/services/ai_tourist_guide_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget testApp(Widget home) => MaterialApp(
  theme: localQuestTheme(),
  home: Scaffold(body: home),
);

const testMerchantUser = AppUser(
  id: 'merchant-test-uid',
  email: 'merchant@localquest.test',
  displayName: 'Merchant Tester',
  username: '@merchant_tester',
  role: AccountRole.merchant,
);

void main() {
  group('Campaign Model & Voucher Classification', () {
    test('Welcome voucher getters and properties', () {
      final welcomeCampaign = Campaign(
        id: 'v-welcome-1',
        ownerId: 'owner-1',
        businessId: 'biz-1',
        name: 'Welcome RM5 Off',
        description: 'First time visit discount for discovering our cafe.',
        type: 'voucher',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 10, 1),
        voucherType: 'welcome',
        collectionMethod: 'discovery_claim',
        discountType: 'fixed',
        discountValue: 5.0,
        perCustomerLimit: 1,
      );

      expect(welcomeCampaign.isWelcomeVoucher, isTrue);
      expect(welcomeCampaign.isSeasonalVoucher, isFalse);
      expect(welcomeCampaign.isPromotionalVoucher, isFalse);
      expect(welcomeCampaign.voucherType, 'welcome');
      expect(welcomeCampaign.collectionMethod, 'discovery_claim');
      expect(welcomeCampaign.perCustomerLimit, 1);
    });

    test('Seasonal voucher getters and properties', () {
      final seasonalCampaign = Campaign(
        id: 'v-seasonal-1',
        ownerId: 'owner-1',
        businessId: 'biz-1',
        name: 'Hari Raya Special 20% Off',
        description: 'Festive season savings on dining and souvenirs.',
        type: 'voucher',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 1),
        voucherType: 'seasonal',
        seasonName: 'Hari Raya Aidilfitri',
        collectionMethod: 'both',
        discountType: 'percentage',
        discountValue: 20.0,
        perCustomerLimit: 2,
      );

      expect(seasonalCampaign.isSeasonalVoucher, isTrue);
      expect(seasonalCampaign.isWelcomeVoucher, isFalse);
      expect(seasonalCampaign.isPromotionalVoucher, isFalse);
      expect(seasonalCampaign.voucherType, 'seasonal');
      expect(seasonalCampaign.seasonName, 'Hari Raya Aidilfitri');
      expect(seasonalCampaign.collectionMethod, 'both');
    });

    test('Promotional voucher with linkedAdId and redemption controls', () {
      final promoCampaign = Campaign(
        id: 'v-promo-1',
        ownerId: 'owner-1',
        businessId: 'biz-1',
        name: 'Heritage Tea 15% Off',
        description: 'Standard promo voucher linked to our ad campaign.',
        type: 'voucher',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 10, 1),
        voucherType: 'promotional',
        collectionMethod: 'both',
        discountType: 'percentage',
        discountValue: 15.0,
        perCustomerLimit: 2,
        linkedAdId: 'demo_ad_penang_fest',
        redemptionHours: '2:00 PM – 6:00 PM (Off-peak)',
        dailyQuota: 30,
      );

      expect(promoCampaign.isPromotionalVoucher, isTrue);
      expect(promoCampaign.linkedAdId, 'demo_ad_penang_fest');
      expect(promoCampaign.redemptionHours, '2:00 PM – 6:00 PM (Off-peak)');
      expect(promoCampaign.dailyQuota, 30);
    });

    test('Backwards compatibility defaults for legacy documents', () {
      final defaultCampaign = Campaign(
        id: 'v-legacy-1',
        ownerId: 'owner-1',
        name: 'Legacy Voucher',
        description: 'Voucher created prior to categorization update.',
        type: 'voucher',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 2, 1),
      );

      expect(defaultCampaign.voucherType, 'promotional');
      expect(defaultCampaign.collectionMethod, 'both');
      expect(defaultCampaign.seasonName, isNull);
      expect(defaultCampaign.linkedAdId, isNull);
      expect(defaultCampaign.redemptionHours, isNull);
      expect(defaultCampaign.dailyQuota, isNull);
    });
  });

  group('DemoDatabaseSeeder Penang-Only Data Integrity', () {
    test('Contains exactly 5 iconic Penang establishments', () {
      final businesses = DemoDatabaseSeeder.sampleMalaysianBusinesses;
      expect(businesses.length, 5);

      final names = businesses.map((b) => b.name).toList();
      expect(names, contains('ChinaHouse Heritage Cafe & Bakery'));
      expect(names, contains('Hameediyah Restaurant 1907'));
      expect(names, contains('Toh Soon Cafe'));
      expect(names, contains('Batu Ferringhi Artisan Batik & Craft'));
      expect(names, contains('Air Itam Sister Curry Mee'));
    });

    test('All businesses have authentic Penang coordinates and postcodes', () {
      for (final biz in DemoDatabaseSeeder.sampleMalaysianBusinesses) {
        // Penang Island latitude is approx between 5.25 and 5.50
        expect(biz.latitude, greaterThan(5.25));
        expect(biz.latitude, lessThan(5.55));
        // Penang Island longitude is approx between 100.15 and 100.40
        expect(biz.longitude, greaterThan(100.15));
        expect(biz.longitude, lessThan(100.40));

        // State must strictly be Pulau Pinang
        expect(biz.state, 'Pulau Pinang');
        expect(biz.postcode, anyOf(startsWith('10'), startsWith('11')));
        expect(biz.phone, startsWith('+60'));
        expect(biz.registrationNumber, isNotEmpty);
      }
    });

    test('Penang vouchers include linked promotional ads and redemption hours', () {
      int totalVouchers = 0;
      int welcomeCount = 0;
      int seasonalCount = 0;
      int promotionalCount = 0;

      for (final biz in DemoDatabaseSeeder.sampleMalaysianBusinesses) {
        expect(biz.vouchers, isNotEmpty);
        for (final v in biz.vouchers) {
          totalVouchers++;
          if (v.voucherType == 'welcome') {
            welcomeCount++;
            expect(v.perCustomerLimit, 1, reason: '${v.name} must have limit 1');
            expect(v.collectionMethod, 'discovery_claim');
          } else if (v.voucherType == 'seasonal') {
            seasonalCount++;
            expect(v.seasonName, isNotNull);
            expect(v.seasonName!.trim(), isNotEmpty);
          } else if (v.voucherType == 'promotional') {
            promotionalCount++;
            if (v.redemptionHours != null) {
              expect(v.redemptionHours, isNotEmpty);
            }
          }
        }
      }

      expect(totalVouchers, greaterThanOrEqualTo(12));
      expect(welcomeCount, 5, reason: 'Each Penang shop has a 1-time welcome voucher');
      expect(seasonalCount, greaterThanOrEqualTo(3));
      expect(promotionalCount, greaterThanOrEqualTo(4));
    });
  });

  group('Merchant Redemption Controls (Operating Hours & Daily Quotas)', () {
    test('Campaign stores structured validDays, validHours, and dailyQuota', () {
      final controlledVoucher = Campaign(
        id: 'v-controlled-1',
        ownerId: 'owner-1',
        businessId: 'biz-1',
        name: 'Off-Peak Coffee Deal',
        description: 'Drive traffic during afternoon lull.',
        type: 'voucher',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 10, 1),
        voucherType: 'promotional',
        validDays: 'Weekdays (Mon–Fri)',
        validHours: '2:00 PM – 5:00 PM (Off-peak)',
        dailyQuota: 25,
      );

      expect(controlledVoucher.validDays, 'Weekdays (Mon–Fri)');
      expect(controlledVoucher.validHours, '2:00 PM – 5:00 PM (Off-peak)');
      expect(controlledVoucher.effectiveHours, '2:00 PM – 5:00 PM (Off-peak)');
      expect(controlledVoucher.dailyQuota, 25);
    });

    test('Seasonal voucher can link to an active ad campaign', () {
      final seasonalWithAd = Campaign(
        id: 'v-seasonal-ad-1',
        ownerId: 'owner-1',
        businessId: 'biz-1',
        name: 'Heritage Month Craft Discount',
        description: 'Festival promotion',
        type: 'voucher',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 10, 1),
        voucherType: 'seasonal',
        seasonName: 'Penang Heritage Month',
        linkedAdId: 'demo_ad_heritage_fest',
      );

      expect(seasonalWithAd.isSeasonalVoucher, isTrue);
      expect(seasonalWithAd.seasonName, 'Penang Heritage Month');
      expect(seasonalWithAd.linkedAdId, 'demo_ad_heritage_fest');
    });
  });

  group('AiTouristGuideService Penang Grounding', () {
    test('Produces context-grounded Penang recommendation without paid API key', () async {
      final guideService = AiTouristGuideService();
      final sampleBiz = Business(
        id: 'demo_biz_chinahouse_penang',
        ownerId: 'owner-1',
        name: 'ChinaHouse Heritage Cafe & Bakery',
        category: 'Food & Beverage',
        address: '153, Beach St, Georgetown',
        phone: '+6042637299',
        area: 'George Town',
        state: 'Pulau Pinang',
        latitude: 5.4144,
        longitude: 100.3392,
      );
      final sampleVoucher = Campaign(
        id: 'v-1',
        ownerId: 'owner-1',
        businessId: sampleBiz.id,
        name: 'George Town Welcome - RM5 Off Cake',
        description: 'First visit treat',
        type: 'voucher',
        voucherType: 'welcome',
        collectionMethod: 'discovery_claim',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );

      final recommendation = await guideService.askGuide(
        userPrompt: 'Where should I go for afternoon tea and dessert?',
        userLat: 5.4144,
        userLng: 100.3392,
        nearbyBusinesses: [sampleBiz],
        activeVouchers: [sampleVoucher],
      );

      expect(recommendation, contains('ChinaHouse Heritage Cafe & Bakery'));
      expect(recommendation, contains('George Town Welcome - RM5 Off Cake'));
      expect(recommendation, contains('Penang'));
    });
  });

  group('CampaignEditor Multi-Step Wizard & Voucher Categorization UI', () {
    testWidgets('Renders step progress header and switches between Welcome and Promo', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testApp(
          const CampaignEditor(
            user: testMerchantUser,
            businessId: 'demo-biz-1',
            initialType: 'voucher',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the step progress header is present
      expect(find.text('1. Details'), findsOneWidget);
      expect(find.text('2. Value & limits'), findsOneWidget);
      expect(find.text('3. Rules & schedule'), findsOneWidget);
      expect(find.text('4. Review & confirm'), findsOneWidget);

      // Verify the voucher category selector segmented button has Welcome and Promo (2 options)
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Promo'), findsOneWidget);
      expect(find.text('Seasonal'), findsNothing,
          reason: 'Seasonal is now an occasion field under Promotional');

      // Default is Promotional, shows occasion field
      expect(
        find.textContaining('Promotional voucher: Standard or seasonal'),
        findsOneWidget,
      );
      expect(find.text('Season / festival occasion (Optional)'), findsOneWidget);

      // Tap 'Welcome'
      await tester.ensureVisible(find.text('Welcome'));
      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Welcome voucher: 1-time gift for tourists'),
        findsOneWidget,
      );
      // Under welcome, season occasion and linked ad are not shown
      expect(find.text('Season / festival occasion (Optional)'), findsNothing);

      // Tap back to 'Promo'
      await tester.ensureVisible(find.text('Promo'));
      await tester.tap(find.text('Promo'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Promotional voucher: Standard or seasonal'),
        findsOneWidget,
      );
      expect(find.text('Season / festival occasion (Optional)'), findsOneWidget);
    });

    testWidgets('Navigates across all 3 steps with step validation and renders redemption rules', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testApp(
          const CampaignEditor(
            user: testMerchantUser,
            businessId: 'demo-biz-1',
            initialType: 'voucher',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0: Offer details
      expect(find.text('1 · Offer details'), findsOneWidget);
      expect(find.text('Next: Value & limits'), findsOneWidget);

      // Fill in Step 0 required fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Voucher name'),
        'Penang Heritage Coffee Voucher',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Enjoy RM10 off authentic Hainanese coffee with traditional kaya toast.',
      );
      await tester.pumpAndSettle();

      // Advance to Step 1
      await tester.ensureVisible(find.text('Next: Value & limits'));
      await tester.tap(find.text('Next: Value & limits'));
      await tester.pumpAndSettle();

      // Step 1: Voucher value & limits
      expect(find.text('2 · Voucher value & limits'), findsOneWidget);
      expect(find.text('Discount (%)'), findsOneWidget);
      expect(find.text('Minimum spend (RM)'), findsOneWidget);
      expect(find.text('Total vouchers available'), findsOneWidget);
      expect(find.text('Limit per customer'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Next: Rules & schedule'), findsOneWidget);

      // Advance to Step 2
      await tester.ensureVisible(find.text('Next: Rules & schedule'));
      await tester.tap(find.text('Next: Rules & schedule'));
      await tester.pumpAndSettle();

      // Step 2: Redemption rules & schedule (no subtitle)
      expect(find.text('3 · Redemption rules & schedule'), findsOneWidget);
      expect(find.text('Valid days'), findsOneWidget);
      expect(find.text('All Days'), findsOneWidget);
      expect(find.text('Valid operating hours (Optional)'), findsOneWidget);
      expect(find.text('Daily redemption quota (Optional)'), findsOneWidget);
      expect(find.text('Terms & conditions'), findsOneWidget);
      expect(find.text('Next: Review & confirm'), findsOneWidget);

      // Enter terms and advance to Step 3 (Review & confirm)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Terms & conditions'),
        'Valid for dine-in and takeaway at Campbell Street branch.',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Next: Review & confirm'));
      await tester.tap(find.text('Next: Review & confirm'));
      await tester.pumpAndSettle();

      // Step 3: Single-page review and confirm
      expect(find.text('4 · Review & confirm'), findsOneWidget);
      expect(find.text('Confirm & save voucher'), findsOneWidget);
      expect(find.text('No poster uploaded'), findsOneWidget);

      // Can navigate back to Step 2 via 'Previous'
      await tester.ensureVisible(find.text('Previous'));
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('3 · Redemption rules & schedule'), findsOneWidget);

      // Can navigate back to Step 1 via 'Previous'
      await tester.ensureVisible(find.text('Previous'));
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('2 · Voucher value & limits'), findsOneWidget);
    });

    testWidgets('preLinkedAdId pre-selects and initializes linked campaign', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const CampaignEditor(
            user: testMerchantUser,
            businessId: 'demo-biz-1',
            initialType: 'voucher',
            preLinkedAdId: 'ad_penang_fest',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 · Offer details'), findsOneWidget);
    });
  });

  group('BusinessEditor Operating Hours Multi-Row Scheduler', () {
    testWidgets(
      'Renders 2-column operating hours with day selector, hours input and add row button',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const BusinessEditor(user: testMerchantUser),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Operating hours'), findsOneWidget);
        expect(find.text('DAY(S) OF WEEK'), findsOneWidget);
        expect(find.text('OPERATING HOURS'), findsOneWidget);
        expect(find.text('Add schedule row'), findsOneWidget);

        // Default row has Daily (Mon–Sun)
        expect(find.text('Daily (Mon–Sun)'), findsOneWidget);

        // Tapping Add schedule row adds another row
        await tester.ensureVisible(find.text('Add schedule row'));
        await tester.tap(find.text('Add schedule row'));
        await tester.pumpAndSettle();

        // Now we should have 2 rows, so Sat–Sun appears and remove button exists
        expect(find.text('Sat–Sun'), findsOneWidget);
        expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));

        // Tapping remove removes the second row
        await tester.tap(find.byIcon(Icons.remove_circle_outline).last);
        await tester.pumpAndSettle();
        expect(find.text('Sat–Sun'), findsNothing);
        expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      },
    );

    testWidgets(
      'Tapping Day(s) of week opens modal sheet with presets and day checkboxes',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const BusinessEditor(user: testMerchantUser),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on Day selector
        await tester.ensureVisible(find.text('Daily (Mon–Sun)'));
        await tester.tap(find.text('Daily (Mon–Sun)'));
        await tester.pumpAndSettle();

        // Bottom sheet is visible
        expect(find.text('Select Operating Days'), findsOneWidget);
        expect(
          find.text('Select 1 day or multiple days for this schedule'),
          findsOneWidget,
        );
        expect(find.text('Mon – Fri'), findsOneWidget);
        expect(find.text('Sat – Sun'), findsOneWidget);
        expect(find.text('Monday'), findsOneWidget);
        expect(find.text('Tuesday'), findsOneWidget);

        // Tap 'Mon – Fri' preset
        await tester.tap(find.text('Mon – Fri'));
        await tester.pumpAndSettle();

        // Tap Apply Days
        await tester.tap(find.text('Apply Days (5 selected)'));
        await tester.pumpAndSettle();

        // Check that the row now displays Mon–Fri
        expect(find.text('Mon–Fri'), findsOneWidget);
      },
    );
  });
}
