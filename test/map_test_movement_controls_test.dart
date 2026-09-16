import 'package:collab/screens/interactive_map/map_test_movement_controls.dart';
import 'package:collab/services/map_test_movement_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildControls({
    required bool enabled,
    required ValueChanged<TestMoveDirection> onMove,
    required VoidCallback onReset,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 260,
            child: MapTestMovementControls(
              enabled: enabled,
              stepMeters: 10,
              onMove: onMove,
              onReset: onReset,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows an explicit test-location warning', (tester) async {
    await tester.pumpWidget(
      buildControls(enabled: true, onMove: (_) {}, onReset: () {}),
    );

    expect(find.text('TEST LOCATION'), findsOneWidget);
    expect(find.text('10 m per tap · Not real GPS'), findsOneWidget);
    expect(
      find.text('For map testing only—not real reward claims.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows send the correct directions and reset works', (
    tester,
  ) async {
    final moves = <TestMoveDirection>[];
    var resets = 0;

    await tester.pumpWidget(
      buildControls(enabled: true, onMove: moves.add, onReset: () => resets++),
    );

    for (final direction in TestMoveDirection.values) {
      await tester.tap(find.byKey(ValueKey('test-move-${direction.name}')));
    }

    await tester.tap(find.byKey(const ValueKey('test-move-reset')));

    expect(moves, TestMoveDirection.values);
    expect(resets, 1);
  });

  testWidgets('disabled controls cannot move or reset', (tester) async {
    final moves = <TestMoveDirection>[];
    var resets = 0;

    await tester.pumpWidget(
      buildControls(enabled: false, onMove: moves.add, onReset: () => resets++),
    );

    for (final direction in TestMoveDirection.values) {
      await tester.tap(find.byKey(ValueKey('test-move-${direction.name}')));
    }

    await tester.tap(find.byKey(const ValueKey('test-move-reset')));

    expect(moves, isEmpty);
    expect(resets, 0);
  });
}
