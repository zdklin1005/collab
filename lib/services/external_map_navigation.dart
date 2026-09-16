import 'package:url_launcher/url_launcher.dart';

typedef NavigationUrlLauncher = Future<bool> Function(Uri uri);

class ExternalMapNavigation {
  const ExternalMapNavigation._();

  static Uri? walkingDirectionsUri({
    required double latitude,
    required double longitude,
  }) {
    final valid =
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;

    if (!valid) return null;

    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'walking',
      'dir_action': 'navigate',
    });
  }

  static Future<bool> openWalkingDirections({
    required double latitude,
    required double longitude,
    NavigationUrlLauncher? launcher,
  }) async {
    final uri = walkingDirectionsUri(latitude: latitude, longitude: longitude);

    if (uri == null) return false;

    try {
      if (launcher != null) {
        return await launcher(uri);
      }

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
