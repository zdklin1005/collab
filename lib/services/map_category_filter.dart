import '../models/map_location.dart';

String _categoryLabel(MapLocation location) {
  final category = location.category.trim();
  return category.isEmpty ? 'Uncategorised' : category;
}

// Preserve the existing helper for compatibility.
String businessCategory(MapLocation location) => _categoryLabel(location);

List<String> _availableCategories(
  Iterable<MapLocation> locations,
  MapLocationType type,
) {
  final categories = <String, String>{};

  for (final location in locations) {
    if (!location.canDisplay || location.type != type) continue;

    final label = _categoryLabel(location);
    categories.putIfAbsent(label.toLowerCase(), () => label);
  }

  return categories.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

List<String> availableBusinessCategories(Iterable<MapLocation> locations) {
  return _availableCategories(locations, MapLocationType.business);
}

List<String> availableLandmarkCategories(Iterable<MapLocation> locations) {
  return _availableCategories(locations, MapLocationType.landmark);
}

List<MapLocation> filterMapLocations(
  Iterable<MapLocation> locations,
  String? selectedCategory, {
  String? selectedLandmarkCategory,
}) {
  final businessFilter = selectedCategory?.trim().toLowerCase();
  final landmarkFilter = selectedLandmarkCategory?.trim().toLowerCase();

  return locations.where((location) {
    if (!location.canDisplay) return false;

    final selected = switch (location.type) {
      MapLocationType.business => businessFilter,
      MapLocationType.landmark => landmarkFilter,
    };

    if (selected == null || selected.isEmpty) return true;

    return _categoryLabel(location).toLowerCase() == selected;
  }).toList();
}
