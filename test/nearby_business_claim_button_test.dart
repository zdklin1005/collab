import 'dart:async';

import 'package:collab/models/localquest_models.dart';
import 'package:collab/screens/interactive_map/business_voucher_claim_check.dart';
import 'package:collab/screens/interactive_map/nearby_business_dialog.dart';
import 'package:collab/services/daily_reward_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 12, 2);

  const business = Business(
    id: 'business-a',
    ownerId: 'merchant-a',
    name: 'Demo café',
    category: 'Food',
    address: 'Test location',
    phone: '',
  );

  Future<void> showSelectedVoucher(
    WidgetTester tester,
    Future<BusinessVoucherClaimStatus> Function(String) onClaim,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyBusinessDialog(
            business: business,
            distanceMeters: 20,
            offers: [
              MapVoucherOffer(
                id: 'offer-a',
                businessId: business.id,
                title: 'Test voucher',
                validFrom: now.subtract(const Duration(hours: 1)),
                expiresAt: now.add(const Duration(hours: 1)),
                remainingStock: 3,
              ),
            ],
            now: () => now,
            onDismiss: () {},
            onViewDetails: () {},
            onClaim: onClaim,
          ),
        ),
      ),
    );

    final select = find.byKey(
      const ValueKey('select-business-voucher-offer-a'),
    );

    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
  }

  Finder claimButton() => find.byType(FilledButton);

  testWidgets('selection does not claim; rapid taps invoke one attempt', (
    tester,
  ) async {
    final pending = Completer<BusinessVoucherClaimStatus>();
    final requestedIds = <String>[];

    await showSelectedVoucher(tester, (id) {
      requestedIds.add(id);
      return pending.future;
    });

    expect(requestedIds, isEmpty);

    await tester.tap(claimButton());
    // No rebuild between taps: also tests the method's busy guard.
    await tester.tap(claimButton());
    await tester.pump();

    expect(requestedIds, ['offer-a']);
    expect(find.text('Processing…'), findsOneWidget);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNull);
    expect(find.textContaining('Success!'), findsNothing);

    final back = find.widgetWithText(TextButton, 'Back to vouchers');
    expect(tester.widget<TextButton>(back).onPressed, isNull);

    pending.complete(BusinessVoucherClaimStatus.demoRecorded);
    await tester.pumpAndSettle();

    expect(find.textContaining('Success!'), findsOneWidget);
    expect(find.text('Already claimed'), findsOneWidget);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save failure permits retry and success locks the button', (
    tester,
  ) async {
    var attempts = 0;

    await showSelectedVoucher(tester, (_) async {
      attempts++;
      return attempts == 1
          ? BusinessVoucherClaimStatus.saveFailed
          : BusinessVoucherClaimStatus.demoRecorded;
    });

    await tester.tap(claimButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('save could not be confirmed'), findsOneWidget);
    expect(find.textContaining('Success!'), findsNothing);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNotNull);

    await tester.tap(claimButton());
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.textContaining('Success!'), findsOneWidget);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNull);
  });

  testWidgets('previous claim locks the button without showing new success', (
    tester,
  ) async {
    await showSelectedVoucher(
      tester,
      (_) async => BusinessVoucherClaimStatus.alreadyClaimed,
    );

    await tester.tap(claimButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('You have already claimed'), findsOneWidget);
    expect(find.textContaining('Success!'), findsNothing);
    expect(find.text('Already claimed'), findsOneWidget);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNull);

    // Revisiting the offer must permit a fresh history check.
    await tester.tap(find.text('Back to vouchers'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('select-business-voucher-offer-a')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Claim demo voucher'), findsOneWidget);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNotNull);
  });

  for (final status in [
    BusinessVoucherClaimStatus.outOfRange,
    BusinessVoucherClaimStatus.locationUnreliable,
    BusinessVoucherClaimStatus.voucherUnavailable,
    BusinessVoucherClaimStatus.historyUnavailable,
    BusinessVoucherClaimStatus.claimInProgress,
  ]) {
    testWidgets('$status does not show success or confirm a claim', (
      tester,
    ) async {
      await showSelectedVoucher(tester, (_) async => status);

      await tester.tap(claimButton());
      await tester.pumpAndSettle();

      expect(find.textContaining('Success!'), findsNothing);
      expect(find.text('Already claimed'), findsNothing);
      expect(find.text('Claim demo voucher'), findsOneWidget);
      expect(tester.widget<FilledButton>(claimButton()).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unexpected callback error restores the button', (tester) async {
    await showSelectedVoucher(tester, (_) async {
      throw StateError('Simulated unexpected error.');
    });

    await tester.tap(claimButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not complete the check'), findsOneWidget);
    expect(find.textContaining('Success!'), findsNothing);
    expect(tester.widget<FilledButton>(claimButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion after dialog disposal causes no widget error', (
    tester,
  ) async {
    final pending = Completer<BusinessVoucherClaimStatus>();

    await showSelectedVoucher(tester, (_) => pending.future);

    await tester.tap(claimButton());
    await tester.pump();

    // Remove the dialog while its callback is still pending.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Other page'))),
    );

    pending.complete(BusinessVoucherClaimStatus.demoRecorded);
    await tester.pumpAndSettle();

    expect(find.text('Other page'), findsOneWidget);
    expect(find.textContaining('Success!'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
