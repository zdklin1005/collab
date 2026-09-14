import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Launches the phone-provided native crop/resize tool (uCrop on Android / TOCropViewController on iOS).
///
/// If running on unsupported environments (such as headless tests or web),
/// gracefully falls back to the in-app interactive cropper [showLqImageCropper].
Future<Uint8List?> cropImageFile({
  required BuildContext context,
  required String sourcePath,
  double? aspectRatioX,
  double? aspectRatioY,
  bool lockAspectRatio = false,
  bool circular = false,
  String title = 'Crop Photo',
}) async {
  try {
    CropAspectRatio? cropRatio;
    CropAspectRatioPreset initPreset = CropAspectRatioPreset.original;
    List<CropAspectRatioPreset> presets = [
      CropAspectRatioPreset.original,
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio4x3,
      CropAspectRatioPreset.ratio16x9,
    ];

    if (aspectRatioX != null && aspectRatioY != null && aspectRatioY > 0) {
      cropRatio = CropAspectRatio(ratioX: aspectRatioX, ratioY: aspectRatioY);
      if (aspectRatioX == 1.0 && aspectRatioY == 1.0) {
        initPreset = CropAspectRatioPreset.square;
        presets = [CropAspectRatioPreset.square];
      } else if ((aspectRatioX / aspectRatioY - 16.0 / 9.0).abs() < 0.05) {
        initPreset = CropAspectRatioPreset.ratio16x9;
        presets = [
          CropAspectRatioPreset.ratio16x9,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.square,
        ];
      } else if ((aspectRatioX / aspectRatioY - 4.0 / 3.0).abs() < 0.05) {
        initPreset = CropAspectRatioPreset.ratio4x3;
        presets = [
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
          CropAspectRatioPreset.square,
        ];
      }
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: lockAspectRatio ? cropRatio : null,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF22C55E),
          dimmedLayerColor: Colors.black.withValues(alpha: 0.75),
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white.withValues(alpha: 0.4),
          showCropGrid: true,
          initAspectRatio: initPreset,
          lockAspectRatio: lockAspectRatio,
          cropStyle: circular ? CropStyle.circle : CropStyle.rectangle,
          aspectRatioPresets: presets,
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: lockAspectRatio,
          cropStyle: circular ? CropStyle.circle : CropStyle.rectangle,
        ),
      ],
    );

    if (cropped != null) {
      return await cropped.readAsBytes();
    }
    return null;
  } catch (_) {
    // Fallback to in-app cropper if native cropper is unavailable
    try {
      if (context.mounted && io.File(sourcePath).existsSync()) {
        final bytes = await io.File(sourcePath).readAsBytes();
        if (!context.mounted) return null;
        final double ratio =
            (aspectRatioX != null && aspectRatioY != null && aspectRatioY > 0)
                ? (aspectRatioX / aspectRatioY)
                : 1.0;
        return showLqImageCropper(
          context: context,
          imageBytes: bytes,
          aspectRatio: ratio,
          lockAspectRatio: lockAspectRatio,
          circularMask: circular,
          title: title,
        );
      }
    } catch (_) {}
    return null;
  }
}

/// Launches the interactive LocalQuest Image Cropper.
///
/// Allows tourists and merchants to pinch-to-zoom, pan, rotate, and crop photos
/// to a designated aspect ratio (e.g. 1:1 for profile picture, 16:9 for business banner,
/// 4:3 for campaign ad / voucher posters).
Future<Uint8List?> showLqImageCropper({
  required BuildContext context,
  required Uint8List imageBytes,
  double aspectRatio = 1.0,
  bool lockAspectRatio = false,
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
    this.aspectRatio = 1.0,
    this.lockAspectRatio = false,
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
  final TransformationController _transformController =
      TransformationController();

  ui.Image? _decodedImage;
  late double _selectedAspectRatio = widget.aspectRatio;
  int _quarterTurns = 0;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _decodeImageBytes();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
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
      // Reset transform on rotation so image stays well-centered
      _transformController.value = Matrix4.identity();
    });
  }

  Future<ui.Image> _rotateImage(ui.Image src, int turns) async {
    if (turns % 4 == 0) return src;
    final int normalizedTurns = turns % 4;
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

  Future<void> _cropAndFinish({
    required Size viewportSize,
    required Rect cropRect,
    required Size childSize,
    required Offset childOffset,
  }) async {
    if (_decodedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Rotate base image if needed
      final rotatedImage = await _rotateImage(_decodedImage!, _quarterTurns);

      // 2. Compute output dimensions preserving sharpness
      final double targetAspect = cropRect.width / cropRect.height;
      int outWidth = 1080;
      int outHeight = (1080 / targetAspect).round();
      if (outHeight > 1080) {
        outHeight = 1080;
        outWidth = (1080 * targetAspect).round();
      }

      // 3. Render cropped viewport to high-res canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Clip canvas to final output size
      canvas.clipRect(Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()));

      // Scale factor from on-screen crop box to final output
      final double scaleToOutput = outWidth / cropRect.width;
      canvas.scale(scaleToOutput);
      canvas.translate(-cropRect.left, -cropRect.top);

      // Apply user's interactive pan & zoom
      final Matrix4 transform = _transformController.value;
      canvas.transform(transform.storage);

      // Translate to child unscaled offset and draw rotated image scaled to childSize
      canvas.translate(childOffset.dx, childOffset.dy);
      final double scaleX = childSize.width / rotatedImage.width;
      final double scaleY = childSize.height / rotatedImage.height;
      canvas.scale(scaleX, scaleY);
      canvas.drawImage(
        rotatedImage,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(outWidth, outHeight);
      final byteData =
          await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

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
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
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
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double totalHeight = constraints.maxHeight;

          // Compute crop box dimensions based on chosen aspect ratio
          const double horizontalPadding = 32.0;
          const double verticalPadding = 24.0;
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

          // Effective dimensions of the rotated image
          final bool isSideways = _quarterTurns % 2 == 1;
          final double effectiveW =
              (isSideways ? _decodedImage!.height : _decodedImage!.width)
                  .toDouble();
          final double effectiveH =
              (isSideways ? _decodedImage!.width : _decodedImage!.height)
                  .toDouble();

          // Calculate initial fit size within crop rectangle
          double childW = cropW;
          double childH = childW * (effectiveH / effectiveW);
          if (childH < cropH) {
            childH = cropH;
            childW = childH * (effectiveW / effectiveH);
          }

          final double childLeft = (totalWidth - childW) / 2.0;
          final double childTop = (totalHeight - childH) / 2.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Interactive pan and zoom layer
              InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.2,
                maxScale: 6.0,
                boundaryMargin: const EdgeInsets.all(1200),
                child: SizedBox(
                  width: totalWidth,
                  height: totalHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        left: childLeft,
                        top: childTop,
                        width: childW,
                        height: childH,
                        child: RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Dark scrim overlay with clear crop window and rule-of-thirds grid
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

              // 3. Error toast if any
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

              // 4. Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4ADE80)),
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
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aspect ratio chips (if ratio unlocked)
              if (!widget.lockAspectRatio) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRatioChip('1:1 (Square)', 1.0),
                      const SizedBox(width: 8),
                      _buildRatioChip('4:3 (Poster)', 4.0 / 3.0),
                      const SizedBox(width: 8),
                      _buildRatioChip('16:9 (Banner)', 16.0 / 9.0),
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
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
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
                  LayoutBuilder(
                    builder: (context, _) => TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              final renderBox =
                                  context.findRenderObject() as RenderBox?;
                              if (renderBox == null) return;
                              // Retrieve LayoutBuilder sizes from context
                              final size = MediaQuery.of(context).size;
                              final double totalWidth = size.width;
                              final double totalHeight = size.height -
                                  kToolbarHeight -
                                  MediaQuery.of(context).padding.top -
                                  (widget.lockAspectRatio ? 70 : 120);

                              const double horizontalPadding = 32.0;
                              const double verticalPadding = 24.0;
                              final double availableW =
                                  totalWidth - (horizontalPadding * 2);
                              final double availableH =
                                  totalHeight - (verticalPadding * 2);

                              double cropW = availableW;
                              double cropH = cropW / _selectedAspectRatio;
                              if (cropH > availableH) {
                                cropH = availableH;
                                cropW = cropH * _selectedAspectRatio;
                              }

                              final double cropLeft =
                                  (totalWidth - cropW) / 2.0;
                              final double cropTop =
                                  (totalHeight - cropH) / 2.0;
                              final Rect cropRect = Rect.fromLTWH(
                                cropLeft,
                                cropTop,
                                cropW,
                                cropH,
                              );

                              final bool isSideways = _quarterTurns % 2 == 1;
                              final double effectiveW = (isSideways
                                      ? _decodedImage!.height
                                      : _decodedImage!.width)
                                  .toDouble();
                              final double effectiveH = (isSideways
                                      ? _decodedImage!.width
                                      : _decodedImage!.height)
                                  .toDouble();

                              double childW = cropW;
                              double childH = childW * (effectiveH / effectiveW);
                              if (childH < cropH) {
                                childH = cropH;
                                childW = childH * (effectiveW / effectiveH);
                              }

                              final double childLeft =
                                  (totalWidth - childW) / 2.0;
                              final double childTop =
                                  (totalHeight - childH) / 2.0;

                              _cropAndFinish(
                                viewportSize: Size(totalWidth, totalHeight),
                                cropRect: cropRect,
                                childSize: Size(childW, childH),
                                childOffset: Offset(childLeft, childTop),
                              );
                            },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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
          _transformController.value = Matrix4.identity();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4ADE80).withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4ADE80) : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF4ADE80) : Colors.white70,
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
  _CropOverlayPainter({
    required this.cropRect,
    required this.circularMask,
  });

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
      ..color = Colors.black.withValues(alpha: 0.72)
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
