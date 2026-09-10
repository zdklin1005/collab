import 'package:collab/data/mock_map_data.dart';
import 'package:collab/screens/interactive_map/demo_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Widget testMap(DateTime Function() clock) {
  return MaterialApp(
    home: Scaffold(
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(3.1390, 101.6869),
          initialZoom: 15,
        ),
        children: [
          // No tile layer: these tests require no internet.
          DemoMapMarkers(now: clock),
        ],
      ),
    ),
  );
}

List<String> displayedRewardIds(WidgetTester tester) {
  final layer = tester.widget<MarkerLayer>(
    find.byType(MarkerLayer),
  );

  return layer.markers
      .map((marker) => (marker.key! as ValueKey<String>).value)
      .where((id) => id.startsWith('daily-v1-'))
      .toList()
    ..sort();
}

List<String> expectedRewardIds(DateTime time) {
  return MockMapData.createDailyRewards(time)
      .where((reward) => reward.canDisplayAt(time))
      .map((reward) => reward.id)
      .toList()
    ..sort();
}

void main() {
  // Malaysia midnight on September 8 is September 7, 16:00 UTC.
  final midnight = DateTime.utc(2026, 9, 7, 16);

  testWidgets('Open map switches rewards after midnight', (tester) async {
    var time = midnight.subtract(const Duration(seconds: 2));

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );

    await tester.pumpWidget(testMap(() => time));

    final previousIds = displayedRewardIds(tester);
    expect(previousIds, expectedRewardIds(time));
    expect(previousIds, isNotEmpty);

    // Change the injected clock, then advance the refresh timer.
    time = midnight;
    await tester.pump(const Duration(seconds: 5));

    final nextIds = displayedRewardIds(tester);
    expect(nextIds, expectedRewardIds(time));
    expect(nextIds, isNotEmpty);
    expect(nextIds.toSet().intersection(previousIds.toSet()), isEmpty);

    // Dispose the map so its periodic timer is cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Resuming after midnight refreshes immediately',
      (tester) async {
    var time = midnight.subtract(const Duration(minutes: 1));

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );

    await tester.pumpWidget(testMap(() => time));
    final previousIds = displayedRewardIds(tester);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );

    time = midnight.add(const Duration(minutes: 10));

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );

    // No five-second wait: resume should refresh the batch itself.
    await tester.pump();

    final nextIds = displayedRewardIds(tester);
    expect(nextIds, expectedRewardIds(time));
    expect(nextIds, isNotEmpty);
    expect(nextIds.toSet().intersection(previousIds.toSet()), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Reopening Discover after midnight uses the new day',
      (tester) async {
    var time = midnight.subtract(const Duration(minutes: 1));

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );

    await tester.pumpWidget(testMap(() => time));
    final previousIds = displayedRewardIds(tester);

    // Simulate leaving Discover and disposing its map.
    await tester.pumpWidget(const SizedBox.shrink());

    time = midnight.add(const Duration(minutes: 10));

    // Simulate opening Discover again.
    await tester.pumpWidget(testMap(() => time));

    final nextIds = displayedRewardIds(tester);
    expect(nextIds, expectedRewardIds(time));
    expect(nextIds, isNotEmpty);
    expect(nextIds.toSet().intersection(previousIds.toSet()), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}