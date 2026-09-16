import 'package:collab/models/map_location.dart';
import 'package:collab/models/reward_marker.dart';
import 'package:collab/services/demo_map_claim_store.dart';
import 'package:collab/screens/interactive_map/reward_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DemoMapClaim makeClaim(RewardType type) {
    final now = DateTime.utc(2026, 9, 10);

    return DemoMapClaim(
      touristId: 'test-tourist',
      collectedAt: now,
      reward: RewardMarker(
        id: 'test-spawn',
        checkpointId: 'test-checkpoint',
        locationType: MapLocationType.business,
        locationId: 'test-business',
        type: type,
        title: type == RewardType.exp ? '100 EXP' : 'Demo café voucher',
        latitude: 5,
        longitude: 100,
        expAmount: type == RewardType.exp ? 100 : 0,
        voucherId: type == RewardType.voucher ? 'test-voucher' : null,
        availableFrom: now,
        expiresAt: now.add(const Duration(days: 1)),
      ),
    );
  }

  testWidgets('EXP success is clearly simulated', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RewardSuccessScreen(
          claim: makeClaim(RewardType.exp),
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('DEMO SUCCESS!'), findsOneWidget);
    expect(find.text('+100 EXP'), findsOneWidget);
    expect(find.text('SIMULATED PROGRESS'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(
      find.text('Your real EXP total and level have not changed.'),
      findsOneWidget,
    );
  });

  testWidgets('voucher success does not claim a real wallet update', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RewardSuccessScreen(
          claim: makeClaim(RewardType.voucher),
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('Demo café voucher'), findsOneWidget);
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
    expect(
      find.text('No real voucher has been added to Rewards.'),
      findsOneWidget,
    );
  });

  testWidgets('compact screen scrolls and Continue works', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var continued = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RewardSuccessScreen(
          claim: makeClaim(RewardType.exp),
          onContinue: () => continued = true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('CONTINUE EXPLORING'));
    await tester.tap(find.text('CONTINUE EXPLORING'));
    await tester.pump();

    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EXP card displays the expected simulated progress', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RewardSuccessScreen(
        claim: makeClaim(RewardType.exp),
        currentLevel: 5,
        demoExpBefore: 2450,
        demoTargetExp: 3000,
        onContinue: () {},
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('Level 5'), findsOneWidget);
  expect(find.text('+100 EXP'), findsOneWidget);
  expect(find.text('2550 EXP · demo total'), findsOneWidget);
  expect(find.text('450 EXP to demo target'), findsOneWidget);

  final bar = tester.widget<LinearProgressIndicator>(
    find.byType(LinearProgressIndicator),
  );

  expect(bar.value, closeTo(2550 / 3000, 0.000001));
});

testWidgets('reaching the demo target does not invent a level-up', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RewardSuccessScreen(
        claim: makeClaim(RewardType.exp),
        currentLevel: 5,
        demoExpBefore: 2950,
        demoTargetExp: 3000,
        onContinue: () {},
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('3050 EXP · demo total'), findsOneWidget);
  expect(find.text('Demo target reached'), findsOneWidget);
  expect(find.text('Level 5'), findsOneWidget);
  expect(find.text('Level 6'), findsNothing);

  final bar = tester.widget<LinearProgressIndicator>(
    find.byType(LinearProgressIndicator),
  );

  expect(bar.value, 1.0);
});

  testWidgets('voucher success does not show an EXP progress card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RewardSuccessScreen(
          claim: makeClaim(RewardType.voucher),
          onContinue: () {},
        ),
      ),
    );

    expect(find.byType(DemoExpProgressCard), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Demo café voucher'), findsOneWidget);
  });
}