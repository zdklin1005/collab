import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/live_business_voucher_details_dialog.dart';

void main() {
  final campaign = Campaign(
    id: 'voucher-1',
    ownerId: 'merchant-1',
    businessId: 'business-1',
    name: 'Quadrant Welcome Voucher',
    description: 'Welcome offer for new customers.',
    type: 'voucher',
    status: 'active',
    startDate: DateTime.utc(2026, 9, 16),
    endDate: DateTime.utc(2026, 10, 16),
    quantity: 100,
    claims: 0,
    minimumSpend: 20,
    discountType: 'percentage',
    discountValue: 10,
    voucherType: 'welcome',
    collectionMethod: 'discovery_claim',
    validDays: 'All Days',
    terms: 'One redemption per tourist.',
  );

  testWidgets('shows live voucher campaign details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) {
                      return LiveBusinessVoucherDetailsDialog(
                        campaign: campaign,
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Quadrant Welcome Voucher'), findsOneWidget);
    expect(find.text('Welcome offer for new customers.'), findsOneWidget);
    expect(find.text('10% discount'), findsOneWidget);
    expect(find.text('100 vouchers remaining'), findsOneWidget);
    expect(find.text('Minimum spend: RM 20.00'), findsOneWidget);
    expect(find.text('Valid days: All Days'), findsOneWidget);
    expect(find.text('One redemption per tourist.'), findsOneWidget);

    await tester.tap(find.text('Back to vouchers'));
    await tester.pumpAndSettle();

    expect(find.text('Quadrant Welcome Voucher'), findsNothing);
  });
}
