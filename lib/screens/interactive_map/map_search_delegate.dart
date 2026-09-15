import 'package:flutter/material.dart';

import '../../models/map_location.dart';
import '../../services/map_location_search.dart';

class MapSearchDelegate extends SearchDelegate<MapLocation?> {
  MapSearchDelegate({
    required List<MapLocation> locations,
    this.informationText =
        'Demo places only. Business category filters also apply here. '
        'Select a result to show it on the map.',
  }) : _locations = List.unmodifiable(locations),
       super(searchFieldLabel: 'Search places', autocorrect: false);

  final List<MapLocation> _locations;
  final String informationText;

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back to map',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildMatches(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildMatches(context);
  }

  Widget _buildMatches(BuildContext context) {
    final results = searchMapLocations(_locations, query);

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFEAF0FF),
            padding: const EdgeInsets.all(12),
            child: Text(
              informationText,
              style: const TextStyle(color: Color(0xFF334466)),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        query.trim().isEmpty
                            ? 'No places are available yet.'
                            : 'No results. Try another place name.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final location = results[index];
                      final isBusiness =
                          location.type == MapLocationType.business;

                      final details = [
                        isBusiness ? 'Business' : 'Landmark',
                        if (location.category.isNotEmpty) location.category,
                      ].join(' · ');

                      return ListTile(
                        key: ValueKey(location.id),
                        leading: Icon(
                          isBusiness
                              ? Icons.storefront_outlined
                              : Icons.account_balance_outlined,
                          color: isBusiness
                              ? const Color(0xFF467A45)
                              : const Color(0xFF8055A6),
                        ),
                        title: Text(location.title),
                        subtitle: Text(details),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => close(context, location),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
