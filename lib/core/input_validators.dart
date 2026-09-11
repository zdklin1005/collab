import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class LqInputValidators {
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static final RegExp emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static final RegExp malaysianPostcodePattern = RegExp(r'\b\d{5}\b');

  /// Validates format of username (without leading '@')
  static String? validateUsernameFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required.';
    }
    final clean = value.trim().startsWith('@')
        ? value.trim().substring(1)
        : value.trim();
    if (clean.length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (clean.length > 20) {
      return 'Username must be 20 characters or fewer.';
    }
    if (!usernamePattern.hasMatch(clean)) {
      return 'Only letters, numbers, and underscores are allowed.';
    }
    return null;
  }

  /// Validates email format strictly against standard RFC patterns
  static String? validateEmailFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final clean = value.trim();
    if (!emailPattern.hasMatch(clean)) {
      return 'Enter a valid email address (e.g. name@example.com).';
    }
    return null;
  }

  /// Validates Malaysian address format
  static String? validateAddressFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required.';
    }
    final clean = value.trim();
    if (clean.length < 8) {
      return 'Please enter a complete street address.';
    }
    return null;
  }

  /// Checks if coordinates are within Malaysian geographic boundaries
  static bool isWithinMalaysia(double latitude, double longitude) {
    // Lat: ~0.8 to ~7.5 N, Lng: ~99.5 to ~119.5 E
    return latitude >= 0.8 &&
        latitude <= 7.5 &&
        longitude >= 99.5 &&
        longitude <= 119.5;
  }

  /// Checks if username is taken in Firestore.
  static Future<bool> Function(String username) checkUsernameAvailability =
      _defaultCheckUsernameAvailability;

  static Future<bool> _defaultCheckUsernameAvailability(
    String username,
  ) async {
    final clean = username.trim().startsWith('@')
        ? username.trim().substring(1)
        : username.trim();
    if (clean.isEmpty) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: '@$clean')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return false;

      final snapWithoutAt = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();
      return snapWithoutAt.docs.isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Checks if email is already registered in Firestore.
  static Future<bool> Function(String email) checkEmailAvailability =
      _defaultCheckEmailAvailability;

  static Future<bool> _defaultCheckEmailAvailability(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: clean)
          .limit(1)
          .get();
      return snap.docs.isEmpty;
    } catch (_) {
      return true;
    }
  }
}
