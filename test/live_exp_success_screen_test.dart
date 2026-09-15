import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/screens/interactive_map/reward_success_screen.dart';
import 'package:collab/services/exp_award_service.dart';
import 'package:collab/services/map_exp_claim_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reward = RewardMarker(
    id: 'exp-slot-1',
    checkpointId: 'landmark:park-1',
    locationType: MapLocationType.landmark,
    locationId: 'park-1',
    type: RewardType.exp,
    title: '100 EXP',
    latitude: 5,
    longitude: 100,
    expAmount: 100,
    availableFrom: DateTime.utc(2026, 9, 15),
    expiresAt: DateTime.utc(2026, 9, 16),
  );

  MapExpClaimResult recorded(int before) {
    return MapExpClaimResult(
      MapExpClaimStatus.recorded,
      receipt: ExpAwardReceipt(
        awardId: MapExpClaimStore.claimIdFor(reward.id),
        previousExp: before,
        newExp: before + 100,
        alreadyAwarded: false,
      ),
    );
  }

  for (final sample in [
    (before: 45, level: 1, remaining: 55, fraction: 0.725),
    (before: 150, level: 2, remaining: 350, fraction: 0.125),
    (before: 100, level: 2, remaining: 400, fraction: 0.0),
  ]) {
    testWidgets('live progress from ${sample.before} EXP', (tester) async {
      var continued = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RewardSuccessScreen.liveExp(
            reward: reward,
            result: recorded(sample.before),
            onContinue: () => continued = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SUCCESS!'), findsOneWidget);
      expect(find.text('DEMO SUCCESS!'), findsNothing);
      expect(find.byType(DemoExpProgressCard), findsNothing);
      expect(find.text('Level ${sample.level}'), findsOneWidget);
      expect(find.text('+100 EXP'), findsOneWidget);
      expect(
        find.text('${sample.remaining} EXP to Level ${sample.level + 1}'),
        findsOneWidget,
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(sample.fraction, 0.0001));

      final button = find.widgetWithText(ElevatedButton, 'CONTINUE EXPLORING');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(continued, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  test('duplicate claim cannot open new live success', () {
    expect(
      () => RewardSuccessScreen.liveExp(
        reward: reward,
        result: const MapExpClaimResult(MapExpClaimStatus.alreadyClaimed),
        onContinue: () {},
      ),
      throwsArgumentError,
    );
  });
}
