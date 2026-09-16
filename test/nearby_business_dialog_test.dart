import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/nearby_business_dialog.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reviews the chosen voucher and returns to the list', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 11, 2);

    const business = Business(
      id: 'business-a',
      ownerId: 'merchant-a',
      name: 'Demo café',
      category: 'Food & Beverage',
      address: 'Test location',
      phone: '',
    );

    MapVoucherOffer offer(String id, String title) {
      return MapVoucherOffer(
        id: id,
        businessId: business.id,
        title: title,
        validFrom: now.subtract(const Duration(hours: 1)),
        expiresAt: now.add(const Duration(hours: 1)),
        remainingStock: 3,
      );
    }

    var dismissCalls = 0;
    var detailCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyBusinessDialog(
            business: business,
            distanceMeters: 20,
            offers: [
              offer('offer-a', 'First voucher'),
              offer('offer-b', 'Second voucher'),
            ],
            now: () => now,
            onDismiss: () => dismissCalls++,
            onViewDetails: () => detailCalls++,
          ),
        ),
      ),
    );

    final secondButton = find.byKey(
      const ValueKey('select-business-voucher-offer-b'),
    );

    await tester.ensureVisible(secondButton);
    await tester.tap(secondButton);
    await tester.pumpAndSettle();

    expect(find.text('Review voucher'), findsOneWidget);
    expect(find.text('Second voucher'), findsOneWidget);
    expect(find.text('First voucher'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Back to vouchers'));
    await tester.pumpAndSettle();

    expect(find.text('Business nearby'), findsOneWidget);
    expect(find.text('First voucher'), findsOneWidget);
    expect(find.text('Second voucher'), findsOneWidget);
    expect(dismissCalls, 0);
    expect(detailCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View details'));
    expect(detailCalls, 1);

    await tester.tap(find.text('Dismiss'));
    expect(dismissCalls, 1);
  });
}