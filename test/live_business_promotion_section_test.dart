import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/live_business_promotion_section.dart';

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

  Campaign ad({
    required String id,
    required String name,
    DateTime? endDate,
  }) {
    return Campaign(
      id: id,
      ownerId: 'merchant-1',
      businessId: 'business-1',
      name: name,
      description: 'Advertisement description',
      type: 'ad',
      status: 'active',
      imageUrl: 'https://example.com/$id.jpg',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: endDate ?? now.add(const Duration(days: 5)),
    );
  }

  Widget buildSection({
    required List<Campaign> campaigns,
    bool compact = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LiveBusinessPromotionSection(
            business: business,
            campaigns: campaigns,
            checkedAt: now,
            compact: compact,
          ),
        ),
      ),
    );
  }

  testWidgets('shows an eligible advertisement', (tester) async {
    await tester.pumpWidget(
      buildSection(
        campaigns: [
          ad(id: 'ad-1', name: 'Coffee promotion'),
        ],
      ),
    );

    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('Coffee promotion'), findsOneWidget);
    expect(find.text('Advertisement description'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('live-business-promotion-image-ad-1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('compact mode shows one advertisement', (tester) async {
    await tester.pumpWidget(
      buildSection(
        compact: true,
        campaigns: [
          ad(
            id: 'first',
            name: 'First promotion',
            endDate: now.add(const Duration(days: 1)),
          ),
          ad(
            id: 'second',
            name: 'Second promotion',
            endDate: now.add(const Duration(days: 2)),
          ),
        ],
      ),
    );

    expect(find.text('First promotion'), findsOneWidget);
    expect(find.text('Second promotion'), findsNothing);
    expect(
      find.byKey(const ValueKey('more-live-business-promotions')),
      findsOneWidget,
    );
    expect(
      find.text('1 more promotion available in business details.'),
      findsOneWidget,
    );
  });

  testWidgets('shows nothing when no advertisements qualify', (
    tester,
  ) async {
    await tester.pumpWidget(buildSection(campaigns: const []));

    expect(find.text('Promotions'), findsNothing);
    expect(
      find.byKey(const ValueKey('no-live-business-promotions')),
      findsOneWidget,
    );
  });
}