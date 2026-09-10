import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'localquest_theme.dart';
import 'localquest_widgets.dart';
import 'merchant_validation.dart';
import '../models/localquest_models.dart';
import '../services/cloudinary_images.dart';
import '../services/localquest_services.dart';

class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({super.key, required this.user});
  final AppUser user;
  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  late String? _url = widget.user.photoUrl;
  bool _busy = false;
  @override
  void didUpdateWidget(covariant ProfilePhotoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.photoUrl != widget.user.photoUrl) {
      _url = widget.user.photoUrl;
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (MerchantValidation.imageType(bytes) == null) {
        throw const PhotoUploadException(
          'Choose a JPG, PNG or WEBP image smaller than 5 MB.',
        );
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: LqCard(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your profile picture',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  ClipOval(
                    child: Image.memory(
                      bytes,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This photo will be stored on Cloudinary and displayed on your profile. Use a non-sensitive image for this prototype.',
                  ),
                  const SizedBox(height: 18),
                  LqButton(
                    label: 'Upload photo',
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      final uploaded = await UserRepository.instance.updatePhoto(
        widget.user.id,
        bytes,
      );
      if (mounted) {
        setState(() => _url = uploaded.url);
        showLqMessage(context, 'Profile picture updated.');
      }
    } on PhotoUploadException catch (error) {
      if (mounted) showLqMessage(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showLqMessage(
          context,
          'Could not save the profile picture. Your previous photo is unchanged. Please retry.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _url == null ? 'Add profile photo' : 'Change profile photo';
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            LqAvatar(
              initials: initialsFor(widget.user.displayName),
              photoUrl: _url,
              shape: LqAvatarShape.roundedSquare,
            ),
            Positioned(
              right: -7,
              bottom: -7,
              child: Material(
                color: LqColors.primary,
                elevation: 3,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 3),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy ? null : _choose,
                  child: Tooltip(
                    message: label,
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Center(
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.white,
                                size: 19,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'JPG, PNG or WEBP · under 5 MB',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
