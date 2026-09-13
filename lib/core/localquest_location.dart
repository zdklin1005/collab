import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'localquest_theme.dart';
import 'localquest_widgets.dart';

class MalaysianAddressComponents {
  const MalaysianAddressComponents({
    this.street = '',
    this.postcode = '',
    this.city = '',
    this.state = '',
    this.fullAddress = '',
  });

  final String street;
  final String postcode;
  final String city;
  final String state;
  final String fullAddress;

  static const List<String> malaysianStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Wilayah Persekutuan Kuala Lumpur',
    'Wilayah Persekutuan Labuan',
    'Wilayah Persekutuan Putrajaya',
  ];

  static String normalizeState(String rawState) {
    final lower = rawState.trim().toLowerCase();
    if (lower.isEmpty) return '';
    if (lower.contains('kuala lumpur') || lower == 'kl') {
      return 'Wilayah Persekutuan Kuala Lumpur';
    }
    if (lower.contains('putrajaya')) {
      return 'Wilayah Persekutuan Putrajaya';
    }
    if (lower.contains('labuan')) {
      return 'Wilayah Persekutuan Labuan';
    }
    if (lower.contains('penang') || lower.contains('pulau pinang')) {
      return 'Pulau Pinang';
    }
    if (lower.contains('malacca') || lower.contains('melaka')) {
      return 'Melaka';
    }
    for (final state in malaysianStates) {
      if (state.toLowerCase() == lower || lower.contains(state.toLowerCase())) {
        return state;
      }
    }
    return rawState.trim();
  }

  static MalaysianAddressComponents parse(
    String raw, {
    String? explicitStreet,
    String? explicitPostcode,
    String? explicitCity,
    String? explicitState,
  }) {
    String postcode = explicitPostcode?.trim() ?? '';
    String state = explicitState != null && explicitState.trim().isNotEmpty
        ? normalizeState(explicitState)
        : '';
    String city = explicitCity?.trim() ?? '';
    String street = explicitStreet?.trim() ?? '';

    final cleanRaw = raw.trim();
    if (postcode.isEmpty) {
      final match = RegExp(r'\b\d{5}\b').firstMatch(cleanRaw);
      if (match != null) {
        postcode = match.group(0)!;
      }
    }

    if (state.isEmpty) {
      for (final s in malaysianStates) {
        if (cleanRaw.toLowerCase().contains(s.toLowerCase())) {
          state = s;
          break;
        }
      }
      if (state.isEmpty) {
        if (cleanRaw.toLowerCase().contains('penang')) {
          state = 'Pulau Pinang';
        } else if (cleanRaw.toLowerCase().contains('kuala lumpur') ||
            RegExp(r'\bkl\b', caseSensitive: false).hasMatch(cleanRaw)) {
          state = 'Wilayah Persekutuan Kuala Lumpur';
        } else if (cleanRaw.toLowerCase().contains('malacca')) {
          state = 'Melaka';
        }
      }
    }

    final rawParts = cleanRaw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final filteredParts = rawParts.where((p) {
      final l = p.toLowerCase();
      return l != 'malaysia';
    }).toList();

    if (city.isEmpty) {
      for (final p in filteredParts) {
        if (state.isNotEmpty && p.toLowerCase() == state.toLowerCase()) continue;
        if (p == postcode) continue;
        if (p.contains(postcode)) {
          final stripped = p.replaceAll(postcode, '').trim();
          if (stripped.isNotEmpty) {
            city = stripped;
            break;
          }
        }
      }
      if (city.isEmpty && filteredParts.length >= 2) {
        for (var i = filteredParts.length - 1; i >= 0; i--) {
          final p = filteredParts[i];
          if (state.isNotEmpty &&
              (p.toLowerCase() == state.toLowerCase() ||
                  p.toLowerCase().contains(state.toLowerCase()))) {
            continue;
          }
          if (p == postcode) continue;
          final stripped = p.replaceAll(RegExp(r'\b\d{5}\b'), '').trim();
          if (stripped.isNotEmpty) {
            city = stripped;
            break;
          }
        }
      }
    }

    if (street.isEmpty) {
      final streetCandidates = <String>[];
      for (final p in filteredParts) {
        final l = p.toLowerCase();
        if (state.isNotEmpty &&
            (l == state.toLowerCase() || l.contains(state.toLowerCase()))) {
          continue;
        }
        if (city.isNotEmpty &&
            (l == city.toLowerCase() || l.contains(city.toLowerCase()))) {
          continue;
        }
        if (p == postcode ||
            p.replaceAll(RegExp(r'\b\d{5}\b'), '').trim().isEmpty) {
          continue;
        }
        streetCandidates.add(p);
      }
      street =
          streetCandidates.isNotEmpty ? streetCandidates.join(', ') : cleanRaw;
    }

    return MalaysianAddressComponents(
      street: street,
      postcode: postcode,
      city: city,
      state: state,
      fullAddress: cleanRaw,
    );
  }
}

class LqLocation {
  const LqLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.street,
    this.postcode,
    this.city,
    this.state,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? street;
  final String? postcode;
  final String? city;
  final String? state;
}

class AddressSuggestion {
  const AddressSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.street = '',
    this.postcode = '',
    this.city = '',
    this.state = '',
  });

  final String label;
  final double latitude;
  final double longitude;
  final String street;
  final String postcode;
  final String city;
  final String state;

  factory AddressSuggestion.fromPhotonFeature(Map<String, dynamic> feature) {
    final properties = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? const {},
    );
    final geometry = Map<String, dynamic>.from(
      feature['geometry'] as Map? ?? const {},
    );
    final coordinates = List<Object?>.from(
      geometry['coordinates'] as List? ?? const [],
    );

    final name = (properties['name'] as String?)?.trim() ?? '';
    final streetName = (properties['street'] as String?)?.trim() ?? '';
    final housenumber = (properties['housenumber'] as String?)?.trim() ?? '';
    final postcodeVal = (properties['postcode'] as String?)?.trim() ?? '';
    final cityVal = ((properties['city'] as String?) ??
            (properties['district'] as String?))
        ?.trim() ??
        '';
    final stateVal = (properties['state'] as String?)?.trim() ?? '';

    String streetPart = '';
    if (housenumber.isNotEmpty && streetName.isNotEmpty) {
      streetPart = '$housenumber, $streetName';
    } else if (streetName.isNotEmpty) {
      streetPart = streetName;
    } else if (name.isNotEmpty) {
      streetPart = name;
    }
    if (name.isNotEmpty && streetPart.isNotEmpty && !streetPart.contains(name)) {
      streetPart = '$name, $streetPart';
    }

    final parts = <String>[
      if (name.isNotEmpty) name,
      if (streetName.isNotEmpty && streetName != name) streetName,
      if (housenumber.isNotEmpty) housenumber,
      if (postcodeVal.isNotEmpty) postcodeVal,
      if (cityVal.isNotEmpty) cityVal,
      if (stateVal.isNotEmpty) stateVal,
      if (properties['country'] case final String value) value,
    ];
    final uniqueParts = <String>[];
    for (final part in parts) {
      final clean = part.trim();
      if (clean.isNotEmpty && !uniqueParts.contains(clean)) {
        uniqueParts.add(clean);
      }
    }
    final fullLabel = uniqueParts.join(', ');
    final parsed = MalaysianAddressComponents.parse(
      fullLabel,
      explicitStreet: streetPart.isNotEmpty ? streetPart : null,
      explicitPostcode: postcodeVal.isNotEmpty ? postcodeVal : null,
      explicitCity: cityVal.isNotEmpty ? cityVal : null,
      explicitState: stateVal.isNotEmpty ? stateVal : null,
    );

    return AddressSuggestion(
      label: fullLabel,
      longitude: (coordinates[0] as num).toDouble(),
      latitude: (coordinates[1] as num).toDouble(),
      street: parsed.street,
      postcode: parsed.postcode,
      city: parsed.city,
      state: parsed.state,
    );
  }
}

class PhotonAddressService {
  const PhotonAddressService();

  Future<AddressSuggestion?> reverse(LqLocation location) async {
    final uri = Uri.https('photon.komoot.io', '/reverse', {
      'lat': '${location.latitude}',
      'lon': '${location.longitude}',
      'limit': '1',
      'lang': 'en',
      'radius': '1',
    });
    final response = await http
        .get(uri, headers: const {'User-Agent': 'LocalQuest/0.1'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Address service returned ${response.statusCode}.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final features = List<Object?>.from(
      payload['features'] as List? ?? const [],
    );
    for (final feature in features.whereType<Map>()) {
      final result = AddressSuggestion.fromPhotonFeature(
        Map<String, dynamic>.from(feature),
      );
      if (result.label.isNotEmpty) return result;
    }
    return null;
  }

  Future<List<AddressSuggestion>> search(String query) async {
    if (query.trim().length < 3) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query.trim(),
      'limit': '5',
      'lang': 'en',
      // Keep suggestions relevant to Malaysia for LocalQuest.
      'bbox': '99.6,0.8,119.3,7.4',
    });
    final response = await http
        .get(uri, headers: const {'User-Agent': 'LocalQuest/0.1'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Address service returned ${response.statusCode}.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final features = List<Object?>.from(
      payload['features'] as List? ?? const [],
    );
    return features
        .whereType<Map>()
        .map(
          (item) => AddressSuggestion.fromPhotonFeature(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.label.isNotEmpty)
        .toList();
  }
}

class LqAddressField extends StatefulWidget {
  const LqAddressField({
    super.key,
    required this.controller,
    required this.label,
    this.initialLocation,
    this.onLocationChanged,
    this.onAddressComponentsChanged,
    this.validator,
    this.service = const PhotonAddressService(),
  });

  final TextEditingController controller;
  final String label;
  final LqLocation? initialLocation;
  final ValueChanged<LqLocation?>? onLocationChanged;
  final ValueChanged<MalaysianAddressComponents>? onAddressComponentsChanged;
  final String? Function(String?)? validator;
  final PhotonAddressService service;

  @override
  State<LqAddressField> createState() => _LqAddressFieldState();
}

class _LqAddressFieldState extends State<LqAddressField> {
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  LqLocation? _location;
  bool _loading = false;
  String? _message;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final request = ++_request;
    if (_location != null) {
      _location = null;
      widget.onLocationChanged?.call(null);
    }
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _message = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await widget.service.search(value);
        if (!mounted || request != _request) return;
        setState(() {
          _suggestions = results;
          _loading = false;
          _message = results.isEmpty ? 'No matching Malaysian address.' : null;
        });
      } catch (_) {
        if (!mounted || request != _request) return;
        setState(() {
          _suggestions = const [];
          _loading = false;
          _message = 'Address suggestions are temporarily unavailable.';
        });
      }
    });
  }

  void _choose(AddressSuggestion suggestion) {
    final components = MalaysianAddressComponents.parse(
      suggestion.label,
      explicitStreet: suggestion.street,
      explicitPostcode: suggestion.postcode,
      explicitCity: suggestion.city,
      explicitState: suggestion.state,
    );
    final location = LqLocation(
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      address: suggestion.label,
      street: components.street,
      postcode: components.postcode,
      city: components.city,
      state: components.state,
    );
    widget.controller.text = components.street.isNotEmpty
        ? components.street
        : suggestion.label;
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _message = null;
      _location = location;
    });
    widget.onLocationChanged?.call(location);
    widget.onAddressComponentsChanged?.call(components);
  }

  Future<void> _openMap() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<LqLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        initialLocation: _location,
        addressService: widget.service,
      ),
    );
    if (result == null || !mounted) return;
    final components = MalaysianAddressComponents.parse(
      result.address ?? widget.controller.text,
      explicitStreet: result.street,
      explicitPostcode: result.postcode,
      explicitCity: result.city,
      explicitState: result.state,
    );
    widget.controller.text = components.street.isNotEmpty
        ? components.street
        : (result.address ?? widget.controller.text);
    setState(() {
      _location = result;
      _suggestions = const [];
      _message = null;
    });
    widget.onLocationChanged?.call(result);
    widget.onAddressComponentsChanged?.call(components);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        controller: widget.controller,
        maxLines: 2,
        validator: widget.validator,
        keyboardType: TextInputType.streetAddress,
        textInputAction: TextInputAction.search,
        onChanged: _changed,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'Start typing a street, building, or postcode',
          suffixIcon: IconButton(
            tooltip: 'Pin location on map',
            onPressed: _openMap,
            icon: const Icon(Icons.map_outlined),
          ),
        ),
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (_suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LqCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var index = 0; index < _suggestions.length; index++) ...[
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: LqColors.primary,
                    ),
                    title: Text(
                      _suggestions[index].label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => _choose(_suggestions[index]),
                  ),
                  if (index != _suggestions.length - 1)
                    const LqDashedDivider(color: LqColors.line),
                ],
              ],
            ),
          ),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 7, left: 4),
          child: Text(
            _message!,
            style: const TextStyle(color: LqColors.muted, fontSize: 11),
          ),
        ),
      if (_location != null)
        Padding(
          padding: const EdgeInsets.only(top: 7, left: 4),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 15,
                color: Color(0xFF46815B),
              ),
              const SizedBox(width: 5),
              Text(
                'Map pin saved',
                style: const TextStyle(
                  color: Color(0xFF46815B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    this.initialLocation,
    required this.addressService,
  });

  final LqLocation? initialLocation;
  final PhotonAddressService addressService;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _mapController = MapController();
  late LatLng _pin = widget.initialLocation == null
      ? const LatLng(3.1390, 101.6869)
      : LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );
  String? _address;
  String? _addressError;
  AddressSuggestion? _lastSuggestion;
  bool _resolvingAddress = false;
  bool _findingCurrentLocation = false;
  int _lookupRequest = 0;

  @override
  void initState() {
    super.initState();
    _address = widget.initialLocation?.address;
    if (_address == null || _address!.isEmpty) _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    final request = ++_lookupRequest;
    setState(() {
      _resolvingAddress = true;
      _addressError = null;
    });
    try {
      final result = await widget.addressService.reverse(
        LqLocation(latitude: _pin.latitude, longitude: _pin.longitude),
      );
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _lastSuggestion = result;
        _address = result?.label;
        _addressError = result == null
            ? 'No nearby address was found. Move the pin and try again.'
            : null;
      });
    } catch (_) {
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _lastSuggestion = null;
        _address = null;
        _addressError =
            'Could not look up this address. Check your connection and retry.';
      });
    } finally {
      if (mounted && request == _lookupRequest) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  void _setPin(LatLng point) {
    setState(() {
      _pin = point;
      _address = null;
      _lastSuggestion = null;
    });
    _resolveAddress();
  }

  Future<void> _useCurrentLocation() async {
    if (_findingCurrentLocation) return;
    setState(() => _findingCurrentLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was not granted.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on Location on this device, then try again.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      _mapController.move(point, 16);
      _setPin(point);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _addressError = error is StateError
            ? error.message
            : 'Could not retrieve the current location. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _findingCurrentLocation = false);
    }
  }

  void _confirm() {
    if (_address == null || _address!.isEmpty) return;
    final components = MalaysianAddressComponents.parse(
      _address!,
      explicitStreet: _lastSuggestion?.street,
      explicitPostcode: _lastSuggestion?.postcode,
      explicitCity: _lastSuggestion?.city,
      explicitState: _lastSuggestion?.state,
    );
    Navigator.pop(
      context,
      LqLocation(
        latitude: _pin.latitude,
        longitude: _pin.longitude,
        address: _address,
        street: components.street,
        postcode: components.postcode,
        city: components.city,
        state: components.state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.sizeOf(context).height * .84,
    decoration: const BoxDecoration(
      color: LqColors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
          child: Row(
            children: [
              const Expanded(
                child: LqTitleBlock(
                  eyebrow: 'Business location',
                  title: 'Pin it on the map',
                  subtitle: 'Drag the map, then tap the exact entrance.',
                ),
              ),
              IconButton(
                tooltip: 'Close map',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const LqDashedDivider(),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pin,
                  initialZoom: widget.initialLocation == null ? 11 : 16,
                  onTap: (_, point) => _setPin(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.localquest.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin,
                        width: 52,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          size: 48,
                          color: LqColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _findingCurrentLocation ? null : _useCurrentLocation,
                    child: Tooltip(
                      message: 'Use my current location',
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: _findingCurrentLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: LqColors.primary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_resolvingAddress)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Finding the nearest address…'),
                  ],
                )
              else if (_address != null)
                Text(
                  _address!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: LqColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  _addressError ?? 'Tap the map to choose a location.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LqColors.muted, fontSize: 12),
                ),
              if (_addressError != null && !_resolvingAddress) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _resolveAddress,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('Retry address lookup'),
                ),
              ],
              const SizedBox(height: 10),
              LqButton(
                label: 'Use this location',
                icon: Icons.location_on_outlined,
                onPressed: _resolvingAddress || _address == null
                    ? null
                    : _confirm,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
