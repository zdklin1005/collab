import 'package:flutter/material.dart';

import '../../services/map_test_movement_controller.dart';

class MapTestMovementControls extends StatelessWidget {
  const MapTestMovementControls({
    super.key,
    required this.enabled,
    required this.stepMeters,
    required this.onMove,
    required this.onReset,
  });

  final bool enabled;
  final double stepMeters;
  final ValueChanged<TestMoveDirection> onMove;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    Widget directionButton(
      TestMoveDirection direction,
      IconData icon,
      String label,
    ) {
      return IconButton(
        key: ValueKey('test-move-${direction.name}'),
        tooltip: 'Move $label',
        onPressed: enabled ? () => onMove(direction) : null,
        icon: Icon(icon),
      );
    }

    return Material(
      color: const Color(0xFFFFF3CD),
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TEST LOCATION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF664D03),
              ),
            ),
            Text(
              '${stepMeters.toStringAsFixed(0)} m per tap · Not real GPS',
              textAlign: TextAlign.center,
            ),
            const Text(
              'For map testing only—not real reward claims.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            directionButton(
              TestMoveDirection.north,
              Icons.arrow_upward,
              'north',
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                directionButton(
                  TestMoveDirection.west,
                  Icons.arrow_back,
                  'west',
                ),
                IconButton(
                  key: const ValueKey('test-move-reset'),
                  tooltip: 'Reset test position',
                  onPressed: enabled ? onReset : null,
                  icon: const Icon(Icons.restart_alt),
                ),
                directionButton(
                  TestMoveDirection.east,
                  Icons.arrow_forward,
                  'east',
                ),
              ],
            ),
            directionButton(
              TestMoveDirection.south,
              Icons.arrow_downward,
              'south',
            ),
          ],
        ),
      ),
    );
  }
}
