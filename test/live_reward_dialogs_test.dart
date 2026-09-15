import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/screens/interactive_map/out_of_range_dialog.dart';
import 'package:collab/screens/interactive_map/reward_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RewardMarker reward(RewardType type) {
    return RewardMarker(
      id: 'reward-1',
      checkpointId: 'landmark:park-1',
      locationType: MapLocationType.landmark,
      locationId: 'park-1',
      type: type,
      title: type == RewardType.exp ? '100 EXP' : 'Coffee voucher',
      latitude: 5,
      longitude: 100,
      expAmount: type == RewardType.exp ? 100 : 0,
      voucherId: type == RewardType.voucher ? 'offer-1' : null,
      availableFrom: DateTime.utc(2026, 9, 15),
      expiresAt: DateTime.utc(2026, 9, 16),
    );
  }

  testWidgets('live EXP reuses the design with collection disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RewardPreviewDialog(
            reward: reward(RewardType.exp),
            locationName: 'Example Park',
            isDemo: false,
          ),
        ),
      ),
    );

    expect(find.text('Reward Nearby!'), findsOneWidget);
    expect(find.text('100 EXP Found'), findsOneWidget);
    expect(find.textContaining('demo', findRichText: true), findsNothing);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'COLLECT REWARD'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live voucher uses the ticket icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RewardPreviewDialog(
            reward: reward(RewardType.voucher),
            locationName: 'Example Park',
            isDemo: false,
          ),
        ),
      ),
    );

    expect(find.text('Voucher Nearby!'), findsOneWidget);
    expect(find.text('Coffee voucher'), findsOneWidget);
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live out-of-range keeps its design and focus action', (
    tester,
  ) async {
    var focused = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutOfRangeDialog(
            distanceMeters: 120,
            radiusMeters: 50,
            isDemo: false,
            onGetCloser: () => focused = true,
          ),
        ),
      ),
    );

    expect(find.text('Too Far Away!'), findsOneWidget);
    expect(find.textContaining('demo', findRichText: true), findsNothing);

    final button = find.widgetWithText(ElevatedButton, 'GET CLOSER');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(focused, isTrue);
    expect(tester.takeException(), isNull);
  });
}
