import '../models/map_location.dart';

List<MapLocation> searchMapLocations(
  Iterable<MapLocation> locations,
  String query,
) {
  final searchText = query.trim().toLowerCase();

  final results = locations.where((location) {
    return location.canDisplay &&
        location.title.toLowerCase().contains(searchText);
  }).toList();

  results.sort((a, b) {
    final byTitle = a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        );

    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  });

  return results;
}