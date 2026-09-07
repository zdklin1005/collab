import '../models/map_location.dart';

String businessCategory(MapLocation location) {
  final category = location.category.trim();
  return category.isEmpty ? 'Uncategorised' : category;
}

List<String> availableBusinessCategories(
  Iterable<MapLocation> locations,
) {
  final categories = <String, String>{};

  for (final location in locations) {
    if (!location.canDisplay ||
        location.type != MapLocationType.business) {
      continue;
    }

    final label = businessCategory(location);
    categories.putIfAbsent(label.toLowerCase(), () => label);
  }

  return categories.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

List<MapLocation> filterMapLocations(
  Iterable<MapLocation> locations,
  String? selectedCategory,
) {
  final selected = selectedCategory?.trim().toLowerCase();

  return locations.where((location) {
    if (!location.canDisplay) return false;

    // Business filters must not hide landmarks.
    if (location.type != MapLocationType.business) return true;

    if (selected == null || selected.isEmpty) return true;

    return businessCategory(location).toLowerCase() == selected;
  }).toList();
}