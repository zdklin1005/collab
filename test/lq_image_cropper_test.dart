import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/core/lq_image_cropper.dart';

Future<Uint8List> createTestPng({int width = 100, int height = 100}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.blue);
  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  testWidgets('LqImageCropperScreen defaults to 16:9 and hides ratio selector when locked', (tester) async {
    late Uint8List bytes;
    await tester.runAsync(() async {
      bytes = await createTestPng(width: 200, height: 150);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LqImageCropperScreen(
          imageBytes: bytes,
          title: 'Crop Business Banner',
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('Crop Business Banner'), findsOneWidget);
    expect(find.text('1:1 (Square)'), findsNothing);
    expect(find.text('4:3 (Poster)'), findsNothing);
    expect(find.text('4:3 (Landscape)'), findsNothing);
    expect(find.text('16:9 (Banner)'), findsNothing);

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_90_degrees_ccw), findsOneWidget);
  });

  testWidgets('LqImageCropperScreen shows 16:9 first when ratio is explicitly unlocked', (tester) async {
    late Uint8List bytes;
    await tester.runAsync(() async {
      bytes = await createTestPng(width: 200, height: 150);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LqImageCropperScreen(
          imageBytes: bytes,
          lockAspectRatio: false,
          title: 'Crop & Resize Photo',
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('16:9 (Banner)'), findsOneWidget);
    expect(find.text('4:3 (Landscape)'), findsOneWidget);
    expect(find.text('1:1 (Square)'), findsOneWidget);
  });
}
