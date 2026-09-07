import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_style.dart';

class MapTilesWithStatus extends StatefulWidget {
  const MapTilesWithStatus({
    super.key,
    this.style = MapStyle.standard,
  });

final MapStyle style;

  @override
  State<MapTilesWithStatus> createState() =>
      _MapTilesWithStatusState();
}

class _MapTilesWithStatusState extends State<MapTilesWithStatus> {
  bool _hasLoadedTile = false;
  bool _hasError = false;
  int _attempt = 0;

  void _reportLoaded(int attempt) {
    if (!mounted || attempt != _attempt || _hasLoadedTile) {
      return;
    }

    // Tile notifications may happen during a widget build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt || _hasLoadedTile) {
        return;
      }

      setState(() {
        _hasLoadedTile = true;
      });
    });
  }

  void _reportError(int attempt) {
    if (!mounted || attempt != _attempt || _hasError) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt || _hasError) {
        return;
      }

      setState(() {
        _hasError = true;
      });
    });
  }

  void _retry() {
    setState(() {
      _attempt++;
      _hasLoadedTile = false;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    final showStatus = !_hasLoadedTile || _hasError;

    return Stack(
      fit: StackFit.expand,
      children: [
        TileLayer(
          // Replace only the tile layer when retrying.
          // The parent map keeps its position and zoom.
          key: ValueKey(attempt),
          urlTemplate: MapStyleConfig.tileUrl(widget.style),
          maxNativeZoom: 19,
          userAgentPackageName: 'com.localquest.app',
          errorTileCallback: (tile, error, stackTrace) {
            // Do not print the error object: its URL may contain the API key.
            debugPrint(
              '${MapStyleConfig.label(widget.style)} tile failed; '
              'attempt: $attempt',
            );
            _reportError(attempt);
          },
          tileBuilder: (context, tileWidget, tile) {
            return ListenableBuilder(
              listenable: tile,
              child: tileWidget,
              builder: (context, child) {
                if (tile.loadError) {
                  _reportError(attempt);
                } else if (tile.imageInfo != null) {
                  _reportLoaded(attempt);
                }

                return child!;
              },
            );
          },
        ),

        if (showStatus)
          Positioned(
            left: 12,
            right: 84,
            bottom: 144,
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_hasError)
                          const Icon(
                            Icons.cloud_off_outlined,
                            color: Colors.orange,
                            size: 22,
                          )
                        else
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hasError
                                ? 'Some map tiles could not load.'
                                : 'Loading map…',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_hasError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Try again with connections available or change the zoom level.'
                        'If Satellite remains unavailable, select Standard.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}