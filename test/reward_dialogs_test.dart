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

  Future<void> openDialog(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
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

  testWidgets('Get Closer requests reward focus', (tester) async {
    var focusRequests = 0;

    await openDialog(
      tester,
      Builder(
        builder: (dialogContext) => OutOfRangeDialog(
          distanceMeters: 80,
          radiusMeters: 25,
          onGetCloser: () {
            focusRequests++;
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    );

    expect(find.text('Too Far Away!'), findsOneWidget);
    expect(find.textContaining('within 25 meters'), findsOneWidget);

    await tester.ensureVisible(find.text('GET CLOSER'));
    await tester.tap(find.text('GET CLOSER'));
    await tester.pumpAndSettle();

    expect(focusRequests, 1);
    expect(find.byType(OutOfRangeDialog), findsNothing);
  });

  testWidgets('closing out-of-range dialog does not request focus', (
    tester,
  ) async {
    var focusRequests = 0;

    await openDialog(
      tester,
      OutOfRangeDialog(
        distanceMeters: 80,
        radiusMeters: 25,
        onGetCloser: () => focusRequests++,
      ),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(focusRequests, 0);
    expect(find.byType(OutOfRangeDialog), findsNothing);
  });

  testWidgets('demo collection button calls its supplied callback', (
    tester,
  ) async {
    var calls = 0;

    await openDialog(
      tester,
      RewardPreviewDialog(
        reward: reward(RewardType.exp),
        locationName: 'Demo café',
        onCollect: () => calls++,
      ),
    );

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );

    await tester.ensureVisible(find.text('COLLECT DEMO REWARD'));
    await tester.tap(find.text('COLLECT DEMO REWARD'));
    await tester.pump();

    expect(calls, 1);
  });
}
