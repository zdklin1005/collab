import 'package:collab/models/map_location.dart';
import 'package:collab/services/reward_checkpoint_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validData() => {
    'locationType': 'landmark',
    'locationId': 'landmark-test',
    'label': ' Park entrance ',
    'latitude': 5.0,
    'longitude': 100.0,
    'active': true,
    'placementApproved': true,
  };

  test('parses an active approved landmark checkpoint', () {
    final checkpoint = parseRewardCheckpoint('checkpoint-test', validData());

    expect(checkpoint, isNotNull);
    expect(checkpoint!.id, 'checkpoint-test');
    expect(checkpoint.locationType, MapLocationType.landmark);
    expect(checkpoint.locationId, 'landmark-test');
    expect(checkpoint.label, 'Park entrance');
    expect(checkpoint.canSpawn, isTrue);
  });

  test('supports business checkpoints and integer coordinates', () {
    final data = validData()
      ..['locationType'] = 'business'
      ..['locationId'] = 'business-test'
      ..['latitude'] = 5
      ..['longitude'] = 100;

    final checkpoint = parseRewardCheckpoint('checkpoint-test', data)!;

    expect(checkpoint.locationType, MapLocationType.business);
    expect(checkpoint.locationId, 'business-test');
    expect(checkpoint.latitude, 5.0);
    expect(checkpoint.longitude, 100.0);
  });

  test('requires explicit active and placement approval booleans', () {
    for (final field in ['active', 'placementApproved']) {
      for (final value in <Object?>[false, null, 'true', 1]) {
        final data = validData()..[field] = value;

        expect(
          parseRewardCheckpoint('checkpoint-test', data),
          isNull,
          reason: '$field must be boolean true',
        );
      }
    }
  });

  test('rejects missing required fields', () {
    for (final field in validData().keys) {
      final data = validData()..remove(field);

      expect(
        parseRewardCheckpoint('checkpoint-test', data),
        isNull,
        reason: 'Missing $field',
      );
    }
  });

  test('rejects invalid types and empty identifiers', () {
    expect(parseRewardCheckpoint('  ', validData()), isNull);

    for (final entry in <String, Object>{
      'locationType': 'unknown',
      'locationId': ' ',
      'label': 123,
      'latitude': '5.0',
      'longitude': '100.0',
    }.entries) {
      final data = validData()..[entry.key] = entry.value;
      expect(parseRewardCheckpoint('checkpoint-test', data), isNull);
    }
  });

  test('rejects invalid coordinates', () {
    for (final latitude in [91.0, -91.0, double.nan, double.infinity]) {
      final data = validData()..['latitude'] = latitude;
      expect(parseRewardCheckpoint('checkpoint-test', data), isNull);
    }

    for (final longitude in [181.0, -181.0, double.nan, double.infinity]) {
      final data = validData()..['longitude'] = longitude;
      expect(parseRewardCheckpoint('checkpoint-test', data), isNull);
    }
  });
}
