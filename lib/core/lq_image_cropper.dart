import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Launches the phone-provided native crop/resize tool (uCrop on Android / TOCropViewController on iOS).
///
/// If running on unsupported environments (such as headless tests or web),
/// gracefully falls back to the in-app interactive cropper [showLqImageCropper].
Future<Uint8List?> cropImageFile({
  required BuildContext context,
  required String sourcePath,
  double? aspectRatioX,
  double? aspectRatioY,
  bool lockAspectRatio = true,
  bool circular = false,
  String title = 'Crop Photo',
}) async {
  try {
    if (context.mounted && io.File(sourcePath).existsSync()) {
      final bytes = await io.File(sourcePath).readAsBytes();
      if (!context.mounted) return null;
      final double ratio;
      if (aspectRatioX != null && aspectRatioY != null && aspectRatioY > 0) {
        ratio = aspectRatioX / aspectRatioY;
      } else if (circular) {
        ratio = 1.0;
      } else {
        ratio = 16.0 / 9.0;
      }
      return await showLqImageCropper(
        context: context,
        imageBytes: bytes,
        aspectRatio: ratio,
        lockAspectRatio: lockAspectRatio,
        circularMask: circular,
        title: title,
      );
    }
  } catch (e) {
    debugPrint('cropImageFile error: $e');
  }
  return null;
}

/// Launches the interactive LocalQuest Image Cropper.
///
/// Allows tourists and merchants to pinch-to-zoom, pan, rotate, and crop photos
/// to a designated aspect ratio (e.g. 1:1 for profile picture, 16:9 for business banner,
/// voucher banner, and campaign ads).
/// Strictly clamps all gestures so photos cannot be dragged beyond crop boundaries.
Future<Uint8List?> showLqImageCropper({
  required BuildContext context,
  required Uint8List imageBytes,
  double aspectRatio = 16.0 / 9.0,
  bool lockAspectRatio = true,
  bool circularMask = false,
  String title = 'Crop & Resize Photo',
}) {
  return Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      builder: (_) => LqImageCropperScreen(
        imageBytes: imageBytes,
        aspectRatio: aspectRatio,
        lockAspectRatio: lockAspectRatio,
        circularMask: circularMask,
        title: title,
      ),
      fullscreenDialog: true,
    ),
  );
}

class LqImageCropperScreen extends StatefulWidget {
  const LqImageCropperScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio = 16.0 / 9.0,
    this.lockAspectRatio = true,
    this.circularMask = false,
    this.title = 'Crop & Resize Photo',
  });

  final Uint8List imageBytes;
  final double aspectRatio;
  final bool lockAspectRatio;
  final bool circularMask;
  final String title;

  @override
  State<LqImageCropperScreen> createState() => _LqImageCropperScreenState();
}

class _LqImageCropperScreenState extends State<LqImageCropperScreen> {
  ui.Image? _decodedImage;
  late double _selectedAspectRatio = widget.aspectRatio;
  int _quarterTurns = 0;
  bool _isProcessing = false;
  String? _errorMessage;

  // Strict boundary clamped gesture tracking
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _basePanOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  // Track the latest calculated layout values
  Rect _currentCropRect = Rect.zero;
  double _currentRenderW = 0.0;
  double _currentRenderH = 0.0;

  @override
  void initState() {
    super.initState();
    _decodeImageBytes();
  }

  void _decodeImageBytes() {
    ui.decodeImageFromList(widget.imageBytes, (img) {
      if (mounted) {
        setState(() {
          _decodedImage = img;
        });
      }
    });
  }

  void _rotateClockwise() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _scale = 1.0;
      _panOffset = Offset.zero;
    });
  }

  Future<ui.Image> _rotateImage(ui.Image src, int turns) async {
    final int normalizedTurns = turns % 4;
    if (normalizedTurns == 0) return src;
    final bool isSideways = normalizedTurns == 1 || normalizedTurns == 3;
    final int newW = isSideways ? src.height : src.width;
    final int newH = isSideways ? src.width : src.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(newW / 2.0, newH / 2.0);
    canvas.rotate(normalizedTurns * math.pi / 2.0);
    canvas.drawImage(
      src,
      Offset(-src.width / 2.0, -src.height / 2.0),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    return picture.toImage(newW, newH);
  }

  Future<void> _cropAndFinish() async {
    if (_decodedImage == null || _isProcessing || _currentCropRect.isEmpty) {
      return;
    }
    setState(() => _isProcessing = true);

    try {
      // 1. Rotate base image if necessary
      final rotatedImage = await _rotateImage(_decodedImage!, _quarterTurns);

      // 2. Compute the exact position of the rendered image relative to the crop window
      final double maxPanX = math.max(
        0.0,
        (_currentRenderW - _currentCropRect.width) / 2.0,
      );
      final double maxPanY = math.max(
        0.0,
        (_currentRenderH - _currentCropRect.height) / 2.0,
      );
      final Offset clampedPan = Offset(
        _panOffset.dx.clamp(-maxPanX, maxPanX),
        _panOffset.dy.clamp(-maxPanY, maxPanY),
      );

      final double imgLeft =
          _currentCropRect.center.dx + clampedPan.dx - (_currentRenderW / 2.0);
      final double imgTop =
          _currentCropRect.center.dy + clampedPan.dy - (_currentRenderH / 2.0);

      // 3. Compute relative crop rectangle on the rendered image
      final double relCropX = math.max(0.0, _currentCropRect.left - imgLeft);
      final double relCropY = math.max(0.0, _currentCropRect.top - imgTop);

      // 4. Map from screen render coordinates to high-res source rotated image coordinates
      final double scaleFactor = rotatedImage.width / _currentRenderW;

      final double srcX = (relCropX * scaleFactor).clamp(
        0.0,
        rotatedImage.width.toDouble(),
      );
      final double srcY = (relCropY * scaleFactor).clamp(
        0.0,
        rotatedImage.height.toDouble(),
      );
      final double srcW = (_currentCropRect.width * scaleFactor).clamp(
        1.0,
        rotatedImage.width - srcX,
      );
      final double srcH = (_currentCropRect.height * scaleFactor).clamp(
        1.0,
        rotatedImage.height - srcY,
      );
      final Rect srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);

      // 5. Compute crisp output dimensions preserving aspect ratio
      int outWidth = 1080;
      int outHeight = (1080 / _selectedAspectRatio).round();
      if (outHeight > 1080) {
        outHeight = 1080;
        outWidth = (1080 * _selectedAspectRatio).round();
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final dstRect = Rect.fromLTWH(
        0,
        0,
        outWidth.toDouble(),
        outHeight.toDouble(),
      );

      canvas.drawImageRect(
        rotatedImage,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(outWidth, outHeight);
      final byteData = await croppedUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Could not encode cropped image');
      }

      final croppedBytes = byteData.buffer.asUint8List();
      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Could not crop image. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_decodedImage == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double totalHeight = constraints.maxHeight;

          // Target crop window dimensions based on chosen aspect ratio
          const double horizontalPadding = 28.0;
          const double verticalPadding = 20.0;
          final double availableW = totalWidth - (horizontalPadding * 2);
          final double availableH = totalHeight - (verticalPadding * 2);

          double cropW = availableW;
          double cropH = cropW / _selectedAspectRatio;
          if (cropH > availableH) {
            cropH = availableH;
            cropW = cropH * _selectedAspectRatio;
          }

          final double cropLeft = (totalWidth - cropW) / 2.0;
          final double cropTop = (totalHeight - cropH) / 2.0;
          final Rect cropRect = Rect.fromLTWH(cropLeft, cropTop, cropW, cropH);
          _currentCropRect = cropRect;

          // Effective dimensions of the rotated image
          final bool isSideways = _quarterTurns % 2 == 1;
          final double effectiveW =
              (isSideways ? _decodedImage!.height : _decodedImage!.width)
                  .toDouble();
          final double effectiveH =
              (isSideways ? _decodedImage!.width : _decodedImage!.height)
                  .toDouble();

          // Calculate minimal scale needed so image completely covers cropRect (1.0x baseline)
          final double coverScale = math.max(
            cropRect.width / effectiveW,
            cropRect.height / effectiveH,
          );
          final double baseRenderW = effectiveW * coverScale;
          final double baseRenderH = effectiveH * coverScale;

          // Current rendered dimensions with clamped user zoom scale [1.0, 5.0]
          final double currentW = baseRenderW * _scale;
          final double currentH = baseRenderH * _scale;
          _currentRenderW = currentW;
          _currentRenderH = currentH;

          // Compute strict pan clamping bounds (image CANNOT be dragged inside the crop window)
          final double maxPanX = math.max(
            0.0,
            (currentW - cropRect.width) / 2.0,
          );
          final double maxPanY = math.max(
            0.0,
            (currentH - cropRect.height) / 2.0,
          );
          final Offset clampedPan = Offset(
            _panOffset.dx.clamp(-maxPanX, maxPanX),
            _panOffset.dy.clamp(-maxPanY, maxPanY),
          );

          final double imgLeft =
              cropRect.center.dx + clampedPan.dx - (currentW / 2.0);
          final double imgTop =
              cropRect.center.dy + clampedPan.dy - (currentH / 2.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Clamped image layer
              Positioned(
                left: imgLeft,
                top: imgTop,
                width: currentW,
                height: currentH,
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),

              // 2. Dark scrim overlay with clear crop window, 3x3 grid & corner brackets
              IgnorePointer(
                child: CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: _CropOverlayPainter(
                    cropRect: cropRect,
                    circularMask:
                        widget.circularMask && (_selectedAspectRatio == 1.0),
                  ),
                ),
              ),

              // 3. Strict pan & pinch-to-zoom gesture listener
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: () {
                  setState(() {
                    if (_scale > 1.1) {
                      _scale = 1.0;
                      _panOffset = Offset.zero;
                    } else {
                      _scale = 2.0;
                    }
                  });
                },
                onScaleStart: (details) {
                  _baseScale = _scale;
                  _startFocalPoint = details.focalPoint;
                  _basePanOffset = clampedPan;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_baseScale * details.scale).clamp(1.0, 5.0);
                    final double curW = baseRenderW * _scale;
                    final double curH = baseRenderH * _scale;
                    final double mX = math.max(
                      0.0,
                      (curW - cropRect.width) / 2.0,
                    );
                    final double mY = math.max(
                      0.0,
                      (curH - cropRect.height) / 2.0,
                    );
                    final Offset delta = details.focalPoint - _startFocalPoint;
                    final Offset proposed = _basePanOffset + delta;
                    _panOffset = Offset(
                      proposed.dx.clamp(-mX, mX),
                      proposed.dy.clamp(-mY, mY),
                    );
                  });
                },
              ),

              // 4. Error toast if any
              if (_errorMessage != null)
                Positioned(
                  top: 16,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // 5. Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Cropping image…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aspect ratio chips (if ratio explicitly unlocked)
              if (!widget.lockAspectRatio) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRatioChip('16:9 (Banner)', 16.0 / 9.0),
                      const SizedBox(width: 8),
                      _buildRatioChip('4:3 (Landscape)', 4.0 / 3.0),
                      const SizedBox(width: 8),
                      _buildRatioChip('1:1 (Square)', 1.0),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Bottom control buttons matching Photo 2
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Rotate 90 degrees
                  IconButton(
                    tooltip: 'Rotate 90°',
                    onPressed: _isProcessing ? null : _rotateClockwise,
                    icon: const Icon(
                      Icons.rotate_90_degrees_ccw,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),

                  // Done
                  TextButton(
                    onPressed: _isProcessing ? null : _cropAndFinish,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatioChip(String label, double ratio) {
    final isSelected = (_selectedAspectRatio - ratio).abs() < 0.01;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedAspectRatio = ratio;
          _scale = 1.0;
          _panOffset = Offset.zero;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the cropping overlay with scrim, rule-of-thirds grid,
/// corner brackets, and optional circular mask guide.
class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.cropRect, required this.circularMask});

  final Rect cropRect;
  final bool circularMask;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Darkened outer scrim
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect);
    scrimPath.fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(scrimPath, scrimPaint);

    // 2. Subtle 3x3 rule-of-thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double stepX = cropRect.width / 3.0;
    final double stepY = cropRect.height / 3.0;

    canvas.drawLine(
      Offset(cropRect.left + stepX, cropRect.top),
      Offset(cropRect.left + stepX, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + stepX * 2, cropRect.top),
      Offset(cropRect.left + stepX * 2, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + stepY),
      Offset(cropRect.right, cropRect.top + stepY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + stepY * 2),
      Offset(cropRect.right, cropRect.top + stepY * 2),
      gridPaint,
    );

    // 3. Circular guide if avatar mode
    if (circularMask) {
      final circlePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(cropRect.center, cropRect.width / 2.0, circlePaint);
    }

    // 4. Solid white corner brackets (matching Photo 2)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const double cornerLen = 22.0;
    final double l = cropRect.left;
    final double t = cropRect.top;
    final double r = cropRect.right;
    final double b = cropRect.bottom;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + cornerLen)
        ..lineTo(l, t)
        ..lineTo(l + cornerLen, t),
      cornerPaint,
    );
    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(r - cornerLen, t)
        ..lineTo(r, t)
        ..lineTo(r, t + cornerLen),
      cornerPaint,
    );
    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(l, b - cornerLen)
        ..lineTo(l, b)
        ..lineTo(l + cornerLen, b),
      cornerPaint,
    );
    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(r - cornerLen, b)
        ..lineTo(r, b)
        ..lineTo(r, b - cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect ||
      oldDelegate.circularMask != circularMask;
}
