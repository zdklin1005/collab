import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../core/merchant_validation.dart';

class PhotoUploadException implements Exception {
  const PhotoUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UploadedPhoto {
  const UploadedPhoto({
    required this.url,
    required this.publicId,
    this.deleteToken,
  });
  final String url;
  final String publicId;
  // Short-lived rollback token; never stored in Firestore or logged.
  final String? deleteToken;
}

/// Prototype-only unsigned uploads. These public identifiers are NOT secrets.
/// Cloudinary's preset must restrict formats/size and disallow overwrites.
/// Production ownership checks and permanent deletion need a trusted backend.
class CloudinaryImages {
  CloudinaryImages({
    this.cloudName = const String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: 'g9podhp8',
    ),
    this.preset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: 'localquest_photos',
    ),
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;
  static final instance = CloudinaryImages();
  final String cloudName;
  final String preset;
  final http.Client Function() _clientFactory;

  Future<UploadedPhoto> upload(Uint8List bytes) async {
    final format = MerchantValidation.imageType(bytes);
    if (format == null) {
      throw const PhotoUploadException(
        'Choose a JPG, PNG or WEBP image smaller than 5 MB.',
      );
    }
    final client = _clientFactory();
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload'),
            )
            ..fields['upload_preset'] = preset
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: 'photo.$format',
              ),
            );
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 60));
      if (response.statusCode == 429) {
        throw const PhotoUploadException(
          'Photo uploads are temporarily limited. Please try again later.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PhotoUploadException(
          response.statusCode == 400 ||
                  response.statusCode == 401 ||
                  response.statusCode == 403
              ? 'Photo upload was rejected. Check the image and LocalQuest upload configuration.'
              : 'Photo storage is unavailable. Your changes have not been saved; please retry.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['secure_url'] as String?;
      final publicId = data['public_id'] as String?;
      final uri = Uri.tryParse(url ?? '');
      if (uri?.scheme != 'https' ||
          uri?.host != 'res.cloudinary.com' ||
          !uri!.path.startsWith('/$cloudName/image/upload/') ||
          publicId == null ||
          publicId.isEmpty ||
          data['resource_type'] != 'image') {
        throw const PhotoUploadException(
          'Photo storage returned an invalid response. Please retry.',
        );
      }
      return UploadedPhoto(
        url: url!,
        publicId: publicId,
        deleteToken: data['delete_token'] as String?,
      );
    } on TimeoutException {
      throw const PhotoUploadException(
        'Photo upload timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const PhotoUploadException(
        'Could not upload the photo. Check your internet connection and retry.',
      );
    } on FormatException {
      throw const PhotoUploadException(
        'Photo storage returned an unreadable response. Please retry.',
      );
    } finally {
      client.close();
    }
  }

  /// Only a newly uploaded asset can be rolled back without server credentials.
  /// Cloudinary delete tokens expire after ten minutes.
  Future<void> rollback(UploadedPhoto photo) async {
    if (photo.deleteToken == null) return;
    final client = _clientFactory();
    try {
      await client
          .post(
            Uri.https('api.cloudinary.com', '/v1_1/$cloudName/delete_by_token'),
            body: {'token': photo.deleteToken!},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Preserve the original save error; administrator cleanup may be needed.
    } finally {
      client.close();
    }
  }
}
