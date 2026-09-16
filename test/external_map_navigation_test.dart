import 'package:collab/services/external_map_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates Google Maps walking directions URL', () {
    final uri = ExternalMapNavigation.walkingDirectionsUri(
      latitude: 5.468650,
      longitude: 100.278300,
    );

    expect(uri, isNotNull);
    expect(uri!.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '5.46865,100.2783');
    expect(uri.queryParameters['travelmode'], 'walking');
    expect(uri.queryParameters['dir_action'], 'navigate');
  });

  test('rejects invalid destination coordinates', () {
    final uri = ExternalMapNavigation.walkingDirectionsUri(
      latitude: 95,
      longitude: 100,
    );

    expect(uri, isNull);
  });

  test('passes the directions URL to the launcher', () async {
    Uri? openedUri;

    final opened = await ExternalMapNavigation.openWalkingDirections(
      latitude: 5.399720,
      longitude: 100.273890,
      launcher: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    expect(opened, isTrue);
    expect(openedUri?.queryParameters['destination'], '5.39972,100.27389');
  });

  test('returns false when the launcher fails', () async {
    final opened = await ExternalMapNavigation.openWalkingDirections(
      latitude: 5.399720,
      longitude: 100.273890,
      launcher: (_) async => throw Exception('Cannot open'),
    );

    expect(opened, isFalse);
  });
}
