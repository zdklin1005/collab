import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/localquest_theme.dart';
import '../core/localquest_widgets.dart';
import '../core/merchant_validation.dart';
import '../services/cloudinary_images.dart';
import '../services/review_service.dart';

/// Lets a tourist rate and review a business they've actually visited.
/// Only reachable from a visited-place entry that has a real
/// [businessId] attached (demo/simulated visits store an empty string
/// and don't get a review action at all — see VisitedPlacesScreen).
class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.userId,
    required this.businessId,
    required this.businessName,
  });

  final String userId;
  final String businessId;
  final String businessName;

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 0;
  final _textController = TextEditingController();
  Uint8List? _photoBytes;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (MerchantValidation.imageType(bytes) == null) {
        if (mounted) {
          showLqMessage(
            context,
            'Choose a JPG, PNG or WEBP image smaller than 5 MB.',
            error: true,
          );
        }
        return;
      }
      setState(() => _photoBytes = bytes);
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not open this photo. Choose another image.',
          error: true,
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_rating == 0) {
      showLqMessage(context, 'Tap a star to rate your experience.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      var photoUrls = const <String>[];
      if (_photoBytes != null) {
        final uploaded = await CloudinaryImages.instance.upload(_photoBytes!);
        photoUrls = [uploaded.url];
      }

      final result = await ReviewService.instance.submitReview(
        uid: widget.userId,
        businessId: widget.businessId,
        businessName: widget.businessName,
        rating: _rating.toDouble(),
        text: _textController.text.trim(),
        photoUrls: photoUrls,
      );

      if (!mounted) return;

      if (!result.success) {
        showLqMessage(
          context,
          result.failureReason ?? 'Could not submit review.',
          error: true,
        );
        return;
      }

      showLqMessage(context, 'Review posted! +${result.expAwarded} EXP');
      Navigator.pop(context, true);
    } on PhotoUploadException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not submit review. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => LqPage(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LqBackButton(label: 'Visited places'),
          const SizedBox(height: 12),
          Text(
            'Review ${widget.businessName}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: LqColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your review helps other travellers find great local spots.',
            style: TextStyle(color: LqColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return IconButton(
                  iconSize: 38,
                  onPressed: () => setState(() => _rating = starIndex),
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF5A623),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          LqCard(
            child: TextField(
              controller: _textController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText:
                    'Tell other travellers about your experience (optional)',
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_photoBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                _photoBytes!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _photoBytes == null ? 'Attach a photo (optional)' : 'Change photo',
            ),
          ),
          const SizedBox(height: 28),
          LqButton(
            label: _submitting ? 'Posting review…' : 'Post review',
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
}
