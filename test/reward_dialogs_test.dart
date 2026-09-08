import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/screens/interactive_map/out_of_range_dialog.dart';
import 'package:collab/screens/interactive_map/reward_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RewardMarker reward(RewardType type) {
    return RewardMarker(
      id: 'test-spawn',
      checkpointId: 'test-checkpoint',
      locationType: MapLocationType.business,
      locationId: 'test-business',
      type: type,
      title: type == RewardType.exp ? '100 EXP' : 'Demo café voucher',
      latitude: 5,
      longitude: 100,
      expAmount: type == RewardType.exp ? 100 : 0,
      voucherId: type == RewardType.voucher ? 'test-offer' : null,
      availableFrom: DateTime.utc(2026, 9, 8),
      expiresAt: DateTime.utc(2026, 9, 9),
    );
  }

  Future<void> openDialog(
    WidgetTester tester,
    Widget dialog,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => dialog,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('EXP preview has disabled collection and can close', (
    tester,
  ) async {
    await openDialog(
      tester,
      RewardPreviewDialog(
        reward: reward(RewardType.exp),
        locationName: 'Demo café',
      ),
    );

    expect(find.text('Reward Nearby!'), findsOneWidget);
    expect(find.text('100 EXP Found'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(RewardPreviewDialog), findsNothing);
  });

  testWidgets('voucher preview uses the voucher title', (tester) async {
    await openDialog(
      tester,
      RewardPreviewDialog(
        reward: reward(RewardType.voucher),
        locationName: 'Demo café',
      ),
    );

    expect(find.text('Voucher Nearby!'), findsOneWidget);
    expect(find.text('Demo café voucher'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
  });

  testWidgets('out-of-range card displays radius and returns to map', (
    tester,
  ) async {
    await openDialog(
      tester,
      const OutOfRangeDialog(
        distanceMeters: 80,
        radiusMeters: 25,
      ),
    );

    expect(find.text('Too Far Away!'), findsOneWidget);
    expect(find.textContaining('25 metres', findRichText: true), findsOneWidget);

    await tester.ensureVisible(find.text('BACK TO MAP'));
    await tester.tap(find.text('BACK TO MAP'));
    await tester.pumpAndSettle();

    expect(find.byType(OutOfRangeDialog), findsNothing);
  });
}