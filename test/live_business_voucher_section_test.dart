import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/live_business_voucher_section.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 12);

  const business = Business(
    id: 'business-1',
    ownerId: 'merchant-1',
    name: 'Test Cafe',
    category: 'Cafe',
    address: 'Penang',
    phone: '012-3456789',
  );

  Campaign campaign({
    required String id,
    String collectionMethod = 'discovery_claim',
    int quantity = 10,
    int claims = 2,
  }) {
    return Campaign(
      id: id,
      ownerId: 'merchant-1',
      businessId: 'business-1',
      name: 'Coffee Discount',
      description: 'Save on your next coffee.',
      type: 'voucher',
      status: 'active',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 5)),
      quantity: quantity,
      claims: claims,
      perCustomerLimit: 1,
      voucherType: 'promotional',
      collectionMethod: collectionMethod,
      discountType: 'percentage',
      discountValue: 10,
    );
  }

  Widget buildSection({
    required List<Campaign> campaigns,
    ValueChanged<Campaign>? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LiveBusinessVoucherSection(
            business: business,
            campaigns: campaigns,
            checkedAt: now,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('shows eligible live voucher details', (tester) async {
    await tester.pumpWidget(
      buildSection(campaigns: [campaign(id: 'voucher-1')]),
    );

    expect(find.text('Available vouchers'), findsOneWidget);
    expect(find.text('Coffee Discount'), findsOneWidget);
    expect(find.text('Save on your next coffee.'), findsOneWidget);
    expect(find.text('10% discount'), findsOneWidget);
    expect(find.text('8 remaining'), findsOneWidget);
    expect(find.text('View voucher'), findsOneWidget);
  });

  testWidgets('does not show map-only voucher campaigns', (tester) async {
    await tester.pumpWidget(
      buildSection(
        campaigns: [
          campaign(id: 'map-only', collectionMethod: 'walk_up_collect'),
        ],
      ),
    );

    expect(
      find.byKey(const ValueKey('no-live-business-vouchers')),
      findsOneWidget,
    );
    expect(find.text('Coffee Discount'), findsNothing);
  });

  testWidgets('returns selected campaign when button is tapped', (
    tester,
  ) async {
    Campaign? selected;

    await tester.pumpWidget(
      buildSection(
        campaigns: [campaign(id: 'voucher-1')],
        onSelected: (campaign) => selected = campaign,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('select-live-business-voucher-voucher-1')),
    );
    await tester.pump();

    expect(selected?.id, 'voucher-1');
  });

  testWidgets('shows empty state when no campaigns are available', (
    tester,
  ) async {
    await tester.pumpWidget(buildSection(campaigns: const []));

    expect(
      find.byKey(const ValueKey('no-live-business-vouchers')),
      findsOneWidget,
    );
  });

  testWidgets('disables a voucher already claimed by the tourist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBusinessVoucherSection(
            business: business,
            campaigns: [campaign(id: 'voucher-1')],
            checkedAt: now,
            claimedVoucherIds: const {'voucher-1'},
            claimHistoryReady: true,
            onSelected: (_) {
              fail('A claimed voucher must not be selectable.');
            },
          ),
        ),
      ),
    );

    expect(find.text('Already claimed'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('select-live-business-voucher-voucher-1')),
    );

    expect(button.onPressed, isNull);
  });
}
