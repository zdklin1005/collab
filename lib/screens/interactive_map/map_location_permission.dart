import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _LocationAccess {
  checking,
  serviceOff,
  denied,
  blocked,
  granted,
  error,
}

class MapLocationPermission extends StatefulWidget {
  
  const MapLocationPermission({
    super.key,
    required this.onAccessChanged,
  });

  final ValueChanged<bool> onAccessChanged;
  

  @override
  State<MapLocationPermission> createState() =>
      _MapLocationPermissionState();
}

class _MapLocationPermissionState
    extends State<MapLocationPermission>
    with WidgetsBindingObserver {
  static const _promptedKey = 'map_location_permission_prompted';

  StreamSubscription<ServiceStatus>? _serviceSubscription;

  _LocationAccess _access = _LocationAccess.checking;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _serviceSubscription = Geolocator.getServiceStatusStream().listen(
    (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
        _checkPermission();
      }
    },
    onError: (Object error) {
      debugPrint('Location service status failed: $error');
    },
  );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkPermission(firstEntry: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _serviceSubscription;
  if (subscription != null) {
    unawaited(subscription.cancel());
  }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck after returning from settings, without prompting again.
      _checkPermission();
    }
  }

  Future<bool> _showLocationExplanation() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Explore with your location'),
          content: const Text(
            'LocalQuest needs location access to show your position '
            'and support nearby reward discovery while you explore.\n\n'
            'You can choose "Not now" and continue browsing the map '
            'without sharing your location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    // Back or tapping outside the dialog also means "Not now".
    return accepted ?? false;
  }

  Future<void> _checkPermission({
    bool firstEntry = false,
    bool request = false,
  }) async {
    if (!mounted || _busy) return;

    setState(() {
      _busy = true;
      _access = _LocationAccess.checking;
    });

    var result = _LocationAccess.error;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!enabled) {
        result = _LocationAccess.serviceOff;
      } else {
        var permission = await Geolocator.checkPermission();
        if (!mounted) return;

        if (permission == LocationPermission.denied) {
          final preferences = await SharedPreferences.getInstance();
          if (!mounted) return;

          final prompted = preferences.getBool(_promptedKey) ?? false;

        // Offer the explanation automatically once.
        // Later attempts happen only when the user taps Allow location.
        if (request || (firstEntry && !prompted)) {
          final accepted = await _showLocationExplanation();
          if (!mounted) return;

          // Remember that we offered the flow, including "Not now".
          await preferences.setBool(_promptedKey, true);
          if (!mounted) return;

          if (accepted) {
            permission = await Geolocator.requestPermission();
            if (!mounted) return;
          }
        }
        }

        result = switch (permission) {
          LocationPermission.whileInUse ||
          LocationPermission.always =>
            _LocationAccess.granted,
          LocationPermission.denied => _LocationAccess.denied,
          LocationPermission.deniedForever => _LocationAccess.blocked,
          _ => _LocationAccess.error,
        };
      }
    } catch (error) {
      debugPrint('Location permission check failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _access = result;
          _busy = false;
        });

        widget.onAccessChanged(result == _LocationAccess.granted);
      }
    }
  }

  Future<void> _openSettings({required bool appSettings}) async {
    try {
      final opened = appSettings
          ? await Geolocator.openAppSettings()
          : await Geolocator.openLocationSettings();

      if (!mounted) return;

      if (!opened) {
        _showSettingsMessage();
      }
    } catch (error) {
      debugPrint('Could not open location settings: $error');
      if (mounted) {
        _showSettingsMessage();
      }
    }
  }

  void _showSettingsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please open your phone settings to change location access.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_access == _LocationAccess.granted) {
      return const SizedBox.shrink();
    }

    final message = switch (_access) {
      _LocationAccess.checking => 'Checking location access…',
      _LocationAccess.serviceOff =>
        'Your phone’s location is off. You can still browse the map.',
      _LocationAccess.denied =>
        'Location access is off. Allow it to show your position. '
            'You can still browse the map.',
      _LocationAccess.blocked =>
        'Allow location in app settings to show your position. '
            'You can still browse the map.',
      _LocationAccess.error =>
        'Could not check location access. You can still browse the map.',
      _LocationAccess.granted => '',
    };

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
            if (!_busy)
              Wrap(
                spacing: 8,
                children: [
                  if (_access == _LocationAccess.serviceOff)
                    TextButton(
                      onPressed: () => _openSettings(appSettings: false),
                      child: const Text('Location settings'),
                    ),
                  if (_access == _LocationAccess.denied)
                    TextButton(
                      onPressed: () => _checkPermission(request: true),
                      child: const Text('Allow location'),
                    ),
                  if (_access == _LocationAccess.blocked)
                    TextButton(
                      onPressed: () => _openSettings(appSettings: true),
                      child: const Text('App settings'),
                    ),
                  TextButton(
                    onPressed: () => _checkPermission(),
                    child: const Text('Check again'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}