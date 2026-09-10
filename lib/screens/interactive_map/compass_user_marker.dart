import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassUserMarker extends StatefulWidget {
  const CompassUserMarker({super.key});

  @override
  State<CompassUserMarker> createState() => _CompassUserMarkerState();
}

class _CompassUserMarkerState extends State<CompassUserMarker>
    with WidgetsBindingObserver {
  StreamSubscription<CompassEvent>? _subscription;
  Future<void> _pendingStop = Future<void>.value();

  double? _heading;
  bool _starting = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _startCompass();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCompass();
    } else {
      _stopCompass();
      setState(() {});
    }
  }

  Future<void> _startCompass() async {
    if (_subscription != null || _starting) return;

    _starting = true;
    final generation = ++_generation;

    await _pendingStop;
    if (!mounted || generation != _generation) return;

    _starting = false;

    try {
      final events = FlutterCompass.events;
      if (events == null) return;

      _subscription = events.listen(
        (event) {
          if (!mounted || generation != _generation) return;

          final value = event.heading;

          // Android can report valid negative compass angles.
          // Only missing or non-finite readings are rejected here.
          if (value == null || !value.isFinite) {
            _hideHeading();
            return;
          }

          // Convert signed angles into the range 0–360 degrees.
          final normalized = ((value % 360) + 360) % 360;
          final previous = _heading;

          if (previous == null) {
            setState(() {
              _heading = normalized;
            });
            return;
          }

          // Take the shortest turn across the 359° / 0° boundary.
          final change = (normalized - previous + 540) % 360 - 180;

          // Ignore tiny changes to reduce visible jitter.
          if (change.abs() < 1) return;

          setState(() {
            _heading = previous + change;
          });
        },
        onError: (Object error) {
          if (!mounted || generation != _generation) return;

          debugPrint('Compass unavailable: $error');
          _hideHeading();
        },
        onDone: () {
          if (!mounted || generation != _generation) return;
          _hideHeading();
        },
        cancelOnError: true,
      );

      debugPrint('Map compass started');
    } catch (error) {
      debugPrint('Could not start compass: $error');
      _hideHeading();
    }
  }

  void _hideHeading() {
    if (!mounted || _heading == null) return;

    setState(() {
      _heading = null;
    });
  }

  void _stopCompass() {
    _generation++;
    _starting = false;
    _heading = null;

    final subscription = _subscription;
    _subscription = null;

    if (subscription != null) {
      _pendingStop = _pendingStop
          .then((_) => subscription.cancel())
          .catchError((Object error) {
        debugPrint('Could not cancel compass: $error');
      });

      debugPrint('Map compass stopped');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCompass();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;

    return Semantics(
      label: heading == null
          ? 'Your position. Compass direction unavailable.'
          : 'Your position and phone-facing direction.',
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (heading != null)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: heading,
                end: heading,
              ),
              duration: const Duration(milliseconds: 120),
              child: const CustomPaint(
                painter: _DirectionConePainter(),
              ),
              builder: (context, angle, child) {
                return Transform.rotate(
                  angle: angle * math.pi / 180,
                  child: child,
                );
              },
            ),

          // Keep the position dot exactly at the marker's centre.
          Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF3267D8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionConePainter extends CustomPainter {
  const _DirectionConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final bounds = Rect.fromCircle(
      center: centre,
      radius: radius,
    );

    // A 60-degree cone, initially pointing toward the top (north).
    final path = Path()
      ..moveTo(centre.dx, centre.dy)
      ..arcTo(
        bounds,
        -math.pi / 2 - math.pi / 6,
        math.pi / 3,
        false,
      )
      ..close();

    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x883267D8),
          Color(0x003267D8),
        ],
      ).createShader(bounds);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DirectionConePainter oldDelegate) {
    return false;
  }
}