import 'package:collab/models/map_location.dart';
import 'package:collab/services/landmark_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> landmarkData() => {
  'title': 'Test Park',
  'category': 'Park & Garden',
  'address': 'Test address',
  'description': 'A demonstration landmark.',
  'latitude': 5.4,
  'longitude': 100.3,
  'active': true,
};

void main() {
  test('parses a valid landmark without a business link', () {
    final result = parseLandmark('test-park', landmarkData());

    expect(result, isNotNull);
    expect(result!.id, 'landmark:test-park');
    expect(result.type, MapLocationType.landmark);
    expect(result.businessId, isNull);
    expect(result.title, 'Test Park');
    expect(result.description, 'A demonstration landmark.');
  });

  test('accepts integer coordinates and an omitted description', () {
    final data = landmarkData()
      ..['latitude'] = 5
      ..['longitude'] = 100
      ..remove('description');

    final result = parseLandmark('test-park', data);

    expect(result, isNotNull);
    expect(result!.latitude, 5.0);
    expect(result.description, '');
  });

  test('rejects missing required fields', () {
    for (final field in [
      'title',
      'category',
      'address',
      'latitude',
      'longitude',
      'active',
    ]) {
      final data = landmarkData()..remove(field);
      expect(parseLandmark('test-park', data), isNull, reason: field);
    }
  });

  test('rejects inactive or incorrectly typed records', () {
    for (final value in [false, 'true', 1]) {
      final data = landmarkData()..['active'] = value;
      expect(parseLandmark('test-park', data), isNull);
    }

    final data = landmarkData()..['latitude'] = '5.4';
    expect(parseLandmark('test-park', data), isNull);

    final malformed = landmarkData()..['description'] = 123;
    expect(parseLandmark('test-park', malformed), isNull);
  });

  test('rejects blank identifiers and labels', () {
    expect(parseLandmark(' ', landmarkData()), isNull);

    for (final field in ['title', 'category', 'address']) {
      final data = landmarkData()..[field] = ' ';
      expect(parseLandmark('test-park', data), isNull, reason: field);
    }
  });

  test('rejects invalid coordinates', () {
    for (final latitude in [91, -91, double.nan, double.infinity]) {
      final data = landmarkData()..['latitude'] = latitude;
      expect(parseLandmark('test-park', data), isNull);
    }

    for (final longitude in [181, -181, double.nan, double.infinity]) {
      final data = landmarkData()..['longitude'] = longitude;
      expect(parseLandmark('test-park', data), isNull);
    }
  });

  test('parses an optional landmark photo URL', () {
    final data = landmarkData()
      ..['photoUrl'] = ' https://example.com/landmark.jpg ';

    final result = parseLandmark('test-park', data);

    expect(result, isNotNull);
    expect(result!.photoUrl, 'https://example.com/landmark.jpg');
  });

  test('rejects an incorrectly typed landmark photo URL', () {
    final data = landmarkData()..['photoUrl'] = 123;

    expect(parseLandmark('test-park', data), isNull);
  });
}
