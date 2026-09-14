import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'localquest_widgets.dart';
import 'lq_image_cropper.dart';
import 'merchant_validation.dart';

class BusinessPhotoField extends StatefulWidget {
  const BusinessPhotoField({
    super.key,
    this.url,
    required this.onChanged,
    this.enabled = true,
  });
  final String? url;
  final ValueChanged<Uint8List?> onChanged;
  final bool enabled;
  @override
  State<BusinessPhotoField> createState() => _BusinessPhotoFieldState();
}

class _BusinessPhotoFieldState extends State<BusinessPhotoField> {
  Uint8List? _bytes;
  bool _picking = false;
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (MerchantValidation.imageType(bytes) == null) {
        showLqMessage(
          context,
          'Choose a JPG, PNG or WEBP image smaller than 5 MB.',
          error: true,
        );
        return;
      }

      final croppedBytes = await cropImageFile(
        context: context,
        sourcePath: image.path,
        aspectRatioX: 16.0,
        aspectRatioY: 9.0,
        lockAspectRatio: false,
        title: 'Crop Business Banner',
      );
      if (croppedBytes == null || !mounted) return;

      setState(() => _bytes = croppedBytes);
      widget.onChanged(croppedBytes);
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not open this photo. Choose another image.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_bytes != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(
            _bytes!,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        )
      else if (widget.url != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            widget.url!,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Text('Business photo unavailable'),
          ),
        ),
      OutlinedButton.icon(
        onPressed: widget.enabled && !_picking ? _pick : null,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_picking ? 'Opening photos…' : 'Choose business photo'),
      ),
      if (_bytes != null)
        TextButton(
          onPressed: widget.enabled
              ? () {
                  setState(() => _bytes = null);
                  widget.onChanged(null);
                }
              : null,
          child: const Text('Discard selected photo'),
        ),
      const Text(
        'Optional · saved when you save the business',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}
