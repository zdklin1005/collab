import 'dart:typed_data';
import 'package:collab/core/input_validators.dart';

class MerchantValidation {
  static String? text(String? value, String label, int min, int max) {
    final length = (value ?? '').trim().length;
    return length < min || length > max
        ? '$label must contain $min–$max characters.'
        : null;
  }

  static String? amount(
    String? value, {
    bool percentage = false,
    bool zero = false,
  }) {
    final input = (value ?? '').trim();
    final number = double.tryParse(input);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input) ||
        number == null ||
        !number.isFinite ||
        number < (zero ? 0 : .01) ||
        number > (percentage ? 100 : 100000)) {
      return percentage
          ? 'Enter a percentage greater than 0 and up to 100.'
          : 'Enter a valid amount with at most two decimal places.';
    }
    return null;
  }

  static String? quantity(String? value) {
    final n = int.tryParse((value ?? '').trim());
    return n == null || n < 1 || n > 100000
        ? 'Enter a whole number from 1 to 100,000.'
        : null;
  }

  static String? phone(String? value) =>
      LqInputValidators.validateMalaysianPhone(value);

  static String? registration(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ||
            RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ()/-]{4,39}$').hasMatch(v)
        ? null
        : 'Check the registration number against your certificate.';
  }

  static String? imageType(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length >= 5 * 1024 * 1024) return null;
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'jpeg';
    if (bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) {
      return 'png';
    }
    if (String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    return null;
  }

  static String uploadError(String code) => switch (code) {
    'unauthorized' =>
      'Image upload was denied. Check the account and Storage access rules.',
    'unauthenticated' =>
      'Your session expired. Sign in again before uploading.',
    'bucket-not-found' || 'project-not-found' || 'no-default-bucket' =>
      'Image storage is not set up for LocalQuest. Enable Storage in Firebase first.',
    'quota-exceeded' =>
      'Image storage has reached its limit. Please try again later.',
    'retry-limit-exceeded' =>
      'Upload timed out. Check your connection and retry.',
    'canceled' => 'Upload cancelled. Your form is still available.',
    _ =>
      'Image upload failed. Check your connection and Firebase Storage setup, then retry.',
  };
}
