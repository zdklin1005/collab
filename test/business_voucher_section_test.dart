import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/business_voucher_section.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 2);

  const business = Business(
    id: 'business-a',
    ownerId: 'merchant-a',
    name: 'Demo café',
    category: 'Food & Beverage',
    address: 'Test location',
    phone: '',
  );

  MapVoucherOffer offer({
    String? id,
    String businessId = 'business-a',
    String title = 'Demo café voucher',
    int stock = 3,
    DateTime? expiresAt,
  }) {
    return MapVoucherOffer(
      id: id ?? 'offer-$businessId',
      businessId: businessId,
      title: title,
      validFrom: now.subtract(const Duration(hours: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
      remainingStock: stock,
    );
  }

  Future<void> showSection(
    WidgetTester tester,
    List<MapVoucherOffer> offers, {
    ValueChanged<MapVoucherOffer>? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusinessVoucherSection(
              business: business,
              offers: offers,
              checkedAt: now,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the matching offer with claiming disabled', (
    tester,
  ) async {
    await showSection(tester, [offer()]);

    expect(find.text('Demo café voucher'), findsOneWidget);
    expect(find.text('Demo availability: 3 remaining'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('does not display another business voucher', (tester) async {
    await showSection(tester, [
      offer(businessId: 'business-b', title: 'Other business voucher'),
    ]);

    expect(find.text('Other business voucher'), findsNothing);
    expect(
      find.text('No vouchers available for this business right now.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('exhausted offer displays the unavailable state', (tester) async {
    await showSection(tester, [offer(stock: 0)]);

    expect(find.text('Demo café voucher'), findsNothing);
    expect(
      find.text('No vouchers available for this business right now.'),
      findsOneWidget,
    );
  });

  testWidgets('multiple offers appear in expiry order and can scroll', (
    tester,
  ) async {
    await showSection(tester, [
      offer(
        id: 'later-offer',
        title: 'Later voucher',
        expiresAt: now.add(const Duration(hours: 2)),
      ),
      offer(
        id: 'sooner-offer',
        title: 'Sooner voucher',
        expiresAt: now.add(const Duration(minutes: 30)),
      ),
    ]);

    expect(find.text('Sooner voucher'), findsOneWidget);
    expect(find.text('Later voucher'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(2));

    expect(
      tester.getTopLeft(find.text('Sooner voucher')).dy,
      lessThan(tester.getTopLeft(find.text('Later voucher')).dy),
    );

    for (final button in tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    )) {
      expect(button.onPressed, isNull);
    }

    await tester.ensureVisible(find.text('Later voucher'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('each button selects its own voucher, not the first offer', (
    tester,
  ) async {
    final first = offer(
      id: 'first-offer',
      title: 'First voucher',
      expiresAt: now.add(const Duration(minutes: 30)),
    );

    final second = offer(
      id: 'second-offer',
      title: 'Second voucher',
      expiresAt: now.add(const Duration(hours: 2)),
    );

    final selections = <MapVoucherOffer>[];

    await showSection(tester, [second, first], onSelected: selections.add);

    // Select the later offer first, despite it appearing second.
    final secondButton = find.byKey(
      const ValueKey('select-business-voucher-second-offer'),
    );

    await tester.ensureVisible(secondButton);
    await tester.tap(secondButton);
    await tester.pump();

    expect(selections, hasLength(1));
    expect(selections.single, same(second));
    expect(selections.single.businessId, business.id);

    final firstButton = find.byKey(
      const ValueKey('select-business-voucher-first-offer'),
    );

    await tester.ensureVisible(firstButton);
    await tester.tap(firstButton);
    await tester.pump();

    expect(selections.map((item) => item.id).toList(), [
      'second-offer',
      'first-offer',
    ]);

    // Selection alone must not consume stock.
    expect(first.remainingStock, 3);
    expect(second.remainingStock, 3);
    expect(tester.takeException(), isNull);
  });
}
