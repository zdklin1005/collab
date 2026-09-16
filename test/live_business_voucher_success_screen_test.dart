import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/reward_success_screen.dart';
import 'package:collab/services/live_business_voucher_claim_service.dart';

void main() {
  final campaign = Campaign(
    id: 'voucher-1',
    ownerId: 'merchant-1',
    businessId: 'business-1',
    name: 'Quadrant Welcome Voucher',
    description: 'Welcome offer',
    type: 'voucher',
    status: 'active',
    startDate: DateTime.utc(2026, 9, 16),
    endDate: DateTime.utc(2026, 10, 16),
    quantity: 100,
    perCustomerLimit: 1,
    voucherType: 'welcome',
    collectionMethod: 'discovery_claim',
  );

  testWidgets('shows success for a recorded business voucher', (tester) async {
    final result = LiveBusinessVoucherClaimResult(
      LiveBusinessVoucherClaimStatus.recorded,
      campaign: campaign,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RewardSuccessScreen.businessVoucher(
          result: result,
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('SUCCESS!'), findsOneWidget);
    expect(find.text('Quadrant Welcome Voucher'), findsOneWidget);
    expect(find.text('Voucher added to Rewards.'), findsOneWidget);
    expect(
      find.text('Your voucher claim was successfully saved.'),
      findsOneWidget,
    );
    expect(find.text('CONTINUE EXPLORING'), findsOneWidget);
  });

  test('rejects a non-recorded business claim', () {
    final result = LiveBusinessVoucherClaimResult(
      LiveBusinessVoucherClaimStatus.alreadyClaimed,
      campaign: campaign,
    );

    expect(
      () => RewardSuccessScreen.businessVoucher(
        result: result,
        onContinue: () {},
      ),
      throwsArgumentError,
    );
  });
}
