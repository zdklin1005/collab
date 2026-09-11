import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BiometricAuthService {
  static BiometricAuthService instance = LocalBiometricAuthService();

  Future<bool> isSupported();
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);
  Future<bool> authenticate({required String localizedReason});
  Future<void> saveLastUser({
    required String email,
    required String role,
    String? token,
  });
  Future<Map<String, String>?> getLastUser();
  Future<void> clearLastUser();
}

class LocalBiometricAuthService implements BiometricAuthService {
  LocalBiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static const _enabledKey = 'lq_biometrics_enabled';
  static const _savedEmailKey = 'lq_biometrics_email';
  static const _savedRoleKey = 'lq_biometrics_role';
  static const _savedTokenKey = 'lq_biometrics_token';

  @override
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isDeviceSupported || canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (!enabled) {
      await clearLastUser();
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final supported = await isSupported();
      if (!supported) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveLastUser({
    required String email,
    required String role,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
    await prefs.setString(_savedRoleKey, role);
    if (token != null) {
      await prefs.setString(_savedTokenKey, token);
    }
  }

  @override
  Future<Map<String, String>?> getLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_savedEmailKey);
    final role = prefs.getString(_savedRoleKey);
    if (email == null || role == null) return null;
    return {
      'email': email,
      'role': role,
      'token': prefs.getString(_savedTokenKey) ?? '',
    };
  }

  @override
  Future<void> clearLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_savedRoleKey);
    await prefs.remove(_savedTokenKey);
  }
}

/// In-memory mock for automated widget and unit testing.
class MockBiometricAuthService implements BiometricAuthService {
  MockBiometricAuthService({
    this.supported = true,
    this.enabled = false,
    this.authSucceeds = true,
    Map<String, String>? initialUser,
  }) : _user = initialUser;

  bool supported;
  bool enabled;
  bool authSucceeds;
  Map<String, String>? _user;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) _user = null;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async =>
      authSucceeds;

  @override
  Future<void> saveLastUser({
    required String email,
    required String role,
    String? token,
  }) async {
    _user = {'email': email, 'role': role, 'token': token ?? ''};
  }

  @override
  Future<Map<String, String>?> getLastUser() async => _user;

  @override
  Future<void> clearLastUser() async {
    _user = null;
  }
}
